//
//  TextController.swift
//  CanvasText
//
//  Created by Sam Soffes on 3/2/16.
//  Copyright © 2016 Canvas Labs, Inc. All rights reserved.
//

#if os(OSX)
	import AppKit
#else
	import UIKit
#endif

import WebKit
import OperationalTransformation
import CanvasNative
import X

typealias Style = (range: NSRange, attributes: Attributes)

public final class TextController: NSObject {

	// MARK: - Properties

	public weak var connectionDelegate: TextControllerConnectionDelegate?
	public weak var displayDelegate: TextControllerDisplayDelegate?
	public weak var annotationDelegate: TextControllerAnnotationDelegate?

	let _textStorage = CanvasTextStorage()
	public var textStorage: NSTextStorage {
		return _textStorage
	}

	private let _layoutManager = LayoutManager()
	public var layoutManager: NSLayoutManager {
		return _layoutManager
	}

	private let _textContainer = TextContainer()
	public var textContainer: NSTextContainer {
		return _textContainer
	}

	public var presentationString: String {
		return textStorage.string
	}

	public private(set) var presentationSelectedRange: NSRange?

	public var focusedBlock: BlockNode? {
		let selection = presentationSelectedRange
		let document = currentDocument
		return selection.flatMap { document.blockAt(presentationLocation: $0.location) }
	}

	public var focusedBlocks: [BlockNode]? {
		let selection = presentationSelectedRange
		let document = currentDocument
		return selection.flatMap { document.blocksIn(presentationRange: $0) }
	}

	public var isCodeFocused: Bool {
		guard let block = focusedBlock else { return false }

		if block is CodeBlock {
			return true
		}

		// TODO: Look for CodeSpan and Link URL

		return false
	}

	public var textContainerInset: EdgeInsets = .zero {
		didSet {
			annotationsController.textContainerInset = textContainerInset
		}
	}

	public var theme: Theme {
		didSet {
			imagesController.theme = theme
		}
	}

	#if !os(OSX)
		public var traitCollection = UITraitCollection(horizontalSizeClass: .Unspecified) {
			didSet {
				traitCollectionDidChange(oldValue)
			}
		}
	#endif

	private var transportController: TransportController?
	private let annotationsController: AnnotationsController
	
	private let imagesController: ImagesController

	private let documentController = DocumentController()

	public var currentDocument: Document {
		return documentController.document
	}

	let serverURL: NSURL
	let accessToken: String
	let organizationID: String
	let canvasID: String

	private var needsTitle = false
	private var needsUnfoldUpdate = false
	private var styles = [Style]()
	private var invalidDisplayRange: NSRange?
	private var nextSelection: NSRange?


	// MARK: - Initializers

	public init(serverURL: NSURL, accessToken: String, organizationID: String, canvasID: String, theme: Theme) {
		self.serverURL = serverURL
		self.accessToken = accessToken
		self.organizationID = organizationID
		self.canvasID = canvasID
		self.theme = theme
		imagesController = ImagesController(theme: theme)

		annotationsController = AnnotationsController(theme: theme)
		
		super.init()
		
		annotationsController.textController = self
		annotationsController.delegate = self

		// Configure Text Kit
		_textContainer.textController = self
		_layoutManager.textController = self
		_layoutManager.layoutDelegate = self
		_textStorage.canvasDelegate = self
		textStorage.delegate = self
		layoutManager.addTextContainer(textContainer)
		textStorage.addLayoutManager(layoutManager)

		documentController.delegate = self
	}


	// MARK: - OT

	public func connect() {
		if connectionDelegate == nil {
			print("[TextController] WARNING: connectionDelegate is nil. If you don't add the web view from textController:willConnectWithWebView: to a view, Operation Transport won't work as expected.")
		}

		let transportController = TransportController(serverURL: serverURL, accessToken: accessToken, organizationID: organizationID, canvasID: canvasID)
		transportController.delegate = self
		transportController.connect()
		self.transportController = transportController
	}

	public func disconnect(withReason reason: String?) {
		transportController?.disconnect(withReason: reason)
		transportController = nil
	}
	
	
	// MARK: - Traits

	#if !os(OSX)
		public func traitCollectionDidChange(previousTraitCollection: UITraitCollection?) {
			layoutAttachments()
			annotationsController.horizontalSizeClass = traitCollection.horizontalSizeClass
		}
	#endif

	public func setTintColor(tintColor: Color) {
		guard tintColor != theme.tintColor else { return }

		theme.tintColor = tintColor

		// Update links
		var styles = [Style]()
		for block in currentDocument.blocks {
			guard let container = block as? NodeContainer else { continue }
			let font = theme.attributes(block: block)[NSFontAttributeName] as? Font ?? theme.fontOfSize(theme.fontSize)
			styles += stylesForSpans(container.subnodes, currentFont: font, onlyTintable: true).0
		}

		if !styles.isEmpty {
			self.styles += styles
			applyStyles()
		}
	}


	// MARK: - Selection

	// Update from Text View
	public func setPresentationSelectedRange(range: NSRange?) {
		setPresentationSelectedRange(range, updateTextView: false)
	}

	// Update from Text Controller
	func setPresentationSelectedRange(range: NSRange?, updateTextView: Bool) {
		presentationSelectedRange = range

		needsUnfoldUpdate = true
		dispatch_async(dispatch_get_main_queue()) { [weak self] in
			self?.updateUnfoldIfNeeded()
			self?.annotationsController.layoutAnnotations()
		}

		if updateTextView, let range = range {
			displayDelegate?.textController(self, didUpdateSelectedRange: range)
		}
	}
	
	
	// MARK: - Styles
	
	/// This should not be called while the text view is editing. Ideally, this will be called in the text view's did
	/// change delegate method.
	public func applyStyles() {
		guard !styles.isEmpty else { return }
		
		for style in styles {
			if style.range.max > textStorage.length || style.range.length < 0 {
				print("WARNING: Invalid style: \(style.range)")
				continue
			}
			
			textStorage.setAttributes(style.attributes, range: style.range)
		}
		
		styles.removeAll()
	}


	// MARK: - Internal

	func blockSpacing(block block: BlockNode) -> BlockSpacing {
		#if os(OSX)
			let horizontalSizeClass = UserInterfaceSizeClass.Unspecified
		#else
			let horizontalSizeClass = traitCollection.horizontalSizeClass
		#endif
		return theme.blockSpacing(block: block, horizontalSizeClass: horizontalSizeClass)
	}


	// MARK: - Private

	private func updateUnfoldIfNeeded() {
		guard needsUnfoldUpdate else { return }

		_layoutManager.unfoldedRange = presentationSelectedRange.flatMap { unfoldableRange(presentationSelectedRange: $0) }

		needsUnfoldUpdate = false
	}

	/// Expand selection to the entire node.
	///
	/// - parameter displaySelection: Range of the selected text in the display text
	/// - returns: Optional presentation range of the expanded selection
	private func unfoldableRange(presentationSelectedRange presentationSelectedRange: NSRange) -> NSRange? {
		let selectedRange: NSRange = {
			var range = presentationSelectedRange
			range.location = max(0, range.location - 1)
			range.length += (presentationSelectedRange.location - range.location) + 1

			let backingRanges = currentDocument.backingRanges(presentationRange: range)
			return backingRanges.reduce(backingRanges[0]) { $0.union($1) }
		}()

		let foldableNodes = currentDocument.nodesIn(backingRange: selectedRange).filter { $0 is Foldable }
		var foldableRanges = ArraySlice<NSRange>(foldableNodes.map { currentDocument.presentationRange(backingRange: $0.range) })

		guard var range = foldableRanges.popFirst() else { return nil }

		for r in foldableRanges {
			range = range.union(r)
		}

		return range
	}

	private func layoutAttachments() {
		var styles = [Style]()
		
		for block in currentDocument.blocks {
			guard let block = block as? Attachable,
				style = attachmentStyle(block: block)
			else { continue }
			
			styles.append(style)
		}
		
		self.styles += styles
		applyStyles()
	}

	// Returns an array of styles and an array of foldable ranges
	private func stylesForBlock(block: BlockNode) -> ([Style], [NSRange]) {
		var range = currentDocument.presentationRange(block: block)

		if range.location == 0 {
			range.length += 1
		} else if range.location > 0 {
			range.location -= 1
			range.length += 1
		}

		range.length = min(range.length, (currentDocument.presentationString as NSString).length - range.location)

		if range.length == 0 {
			return ([], [])
		}

		let attributes = theme.attributes(block: block)

		var styles = [Style(range: range, attributes: attributes)]
		var foldableRanges = [NSRange]()

		if let font = attributes[NSFontAttributeName] as? Font {
			// Foldable attributes
			if let foldable = block as? Foldable {
				let foldableAttributes = theme.foldingAttributes(currentFont: font)

				for backingRange in foldable.foldableRanges {
					let style = Style(
						range: currentDocument.presentationRange(backingRange: backingRange),
						attributes: foldableAttributes
					)
					styles.append(style)
					foldableRanges.append(style.range)
				}
			}

			// Contained nodes
			if let container = block as? NodeContainer {
				let (innerStyles, innerFoldableRanges) = stylesForSpans(container.subnodes, currentFont: font)
				styles += innerStyles
				foldableRanges += innerFoldableRanges
			}
		}

		return (styles, foldableRanges)
	}

	// Returns an array of styles and an array of foldable ranges
	private func stylesForSpans(spans: [SpanNode], currentFont: Font, onlyTintable: Bool = false) -> ([Style], [NSRange]) {
		var styles = [Style]()
		var foldableRanges = [NSRange]()

		for span in spans {
			guard let attributes = theme.attributes(span: span, currentFont: currentFont) else { continue }

			let font: Font

			if (onlyTintable && span is Link) || !onlyTintable {
				let style = Style(
					range: currentDocument.presentationRange(backingRange: span.visibleRange),
					attributes: attributes
				)
				styles.append(style)

				font = attributes[NSFontAttributeName] as? Font ?? currentFont
				let foldableAttributes = theme.foldingAttributes(currentFont: font)

				// Foldable attributes
				if let foldable = span as? Foldable {
					// Forward the background color
					var attrs = foldableAttributes
					attrs[NSBackgroundColorAttributeName] = attributes[NSBackgroundColorAttributeName]

					for backingRange in foldable.foldableRanges {
						let style = Style(
							range: currentDocument.presentationRange(backingRange: backingRange),
							attributes: attrs
						)
						styles.append(style)
						foldableRanges.append(style.range)
					}
				}

				// Special case for link URL and title. Maybe we should consider having Themes emit Styles instead of
				// attributes or at least have a style controller for all of this logic.
				if let link = span as? Link {
					var attrs = foldableAttributes
					attrs[NSForegroundColorAttributeName] = theme.linkURLColor

					styles.append(Style(range: currentDocument.presentationRange(backingRange: link.urlRange), attributes: attrs))

					if let title = link.title {
						styles.append(Style(range: currentDocument.presentationRange(backingRange: title.textRange), attributes: attrs))
					}
				}
			} else {
				font = currentFont
			}

			if let container = span as? NodeContainer {
				let (innerStyles, innerFoldableRanges) = stylesForSpans(container.subnodes, currentFont: font)
				styles += innerStyles
				foldableRanges += innerFoldableRanges
			}
		}

		return (styles, foldableRanges)
	}

	private func submitOperations(edits edits: [Edit]) {
		for edit in edits {
			submitOperations(backingRange: edit.range, string: edit.string)
		}
	}

	private func submitOperations(backingRange backingRange: NSRange, string: String) {
		guard let transportController = transportController else {
			print("[TextController] WARNING: Tried to submit an operation without a connection.")
			return
		}

		// Insert
		if backingRange.length == 0 {
			transportController.submit(operation: .insert(location: UInt(backingRange.location), string: string))
			return
		}

		// Remove
		transportController.submit(operation: .remove(location: UInt(backingRange.location), length: UInt(backingRange.length)))

		// Insert after removing
		if backingRange.length > 0 {
			transportController.submit(operation: .insert(location: UInt(backingRange.location), string: string))
		}
	}
	
	private func attachmentStyle(block block: Attachable) -> Style? {
		let attachment: NSTextAttachment
		
		// Horizontal rule
//		if block is HorizontalRule {
//			guard let image = HorizontalRuleAttachment.image(theme: theme) else { return nil }
//			
//			attachment = NSTextAttachment()
//			attachment.image = image
//			attachment.bounds = CGRect(x: 0, y: 0, width: textContainer.size.width, height: HorizontalRuleAttachment.height)
//		}

		// Image
		if let block = block as? CanvasNative.Image {
			let URL = displayDelegate?.textController(self, URLForImage: block) ?? block.url

			#if os(OSX)
				// TODO: Use real scale
				let scale: CGFloat = 2
			#else
				let scale = traitCollection.displayScale
			#endif

			var size = attachmentSize(imageSize: block.size)
			let image = imagesController.fetchImage(
				ID: block.identifier,
				URL: URL,
				size: size,
				scale: scale,
				completion: updateImageAttachment
			)

			if let image = image {
				size = attachmentSize(imageSize: image.size)
			}
			
			attachment = NSTextAttachment()
			attachment.image = image
			attachment.bounds = CGRect(origin: .zero, size: size)
		}
		
		// Missing attachment
		else {
			print("[TextController] WARNING: Missing attachment for block \(block)")
			return nil
		}
		
		let range = currentDocument.presentationRange(block: block)
		return Style(range: range, attributes: [
			NSAttachmentAttributeName: attachment
		])
	}
	
	private func attachmentSize(imageSize input: CGSize?) -> CGSize {
		let imageSize = input ?? CGSize(width: floor(textContainer.size.width), height: 300)
		let width = min(floor(textContainer.size.width), imageSize.width)
		var size = imageSize
		
		size.height = floor(width * size.height / size.width)
		size.width = width
		
		return size
	}
	
	private func blockForImageID(ID: String) -> CanvasNative.Image? {
		for block in currentDocument.blocks {
			if let image = block as? CanvasNative.Image where image.identifier == ID {
				return image
			}
		}
		
		return nil
	}
	
	private func updateImageAttachment(ID ID: String, image: X.Image?) {
		guard let image = image, block = blockForImageID(ID) else { return }
		
		let attachment = NSTextAttachment()
		attachment.image = image
		attachment.bounds = CGRect(origin: .zero, size: attachmentSize(imageSize: image.size))
		
		let range = currentDocument.presentationRange(block: block)
		let style = Style(range: range, attributes: [
			NSAttachmentAttributeName: attachment
		])
		
		styles.append(style)
		applyStyles()
	}
}


extension TextController: TransportControllerDelegate {
	public func transportController(controller: TransportController, willConnectWithWebView webView: WKWebView) {
		connectionDelegate?.textController(self, willConnectWithWebView: webView)
	}

	public func transportController(controller: TransportController, didReceiveSnapshot text: String) {
		let bounds = NSRange(location: 0, length: (currentDocument.backingString as NSString).length)

		// Ensure we have a valid document
		var string = text
		if string.isEmpty {
			string = Title.nativeRepresentation()
			submitOperations(backingRange: bounds, string: string)
		}

		setNeedsTitleUpdate()
		displayDelegate?.textControllerWillProcessRemoteEdit(self)
		documentController.replaceCharacters(inBackingRange: bounds, withString: string)
		connectionDelegate?.textControllerDidConnect(self)
		displayDelegate?.textControllerDidProcessRemoteEdit(self)
		
		applyStyles()
		annotationsController.layoutAnnotations()
	}

	public func transportController(controller: TransportController, didReceiveOperation operation: Operation) {
		displayDelegate?.textControllerWillProcessRemoteEdit(self)

		switch operation {
		case .insert(let location, let string):
			let range = NSRange(location: Int(location), length: 0)
			documentController.replaceCharacters(inBackingRange: range, withString: string)

		case .remove(let location, let length):
			let range = NSRange(location: Int(location), length: Int(length))
			documentController.replaceCharacters(inBackingRange: range, withString: "")
		}

		displayDelegate?.textControllerDidProcessRemoteEdit(self)
	}

	public func transportController(controller: TransportController, didReceiveWebErrorMessage errorMessage: String?, lineNumber: UInt?, columnNumber: UInt?) {
		print("[TextController] TransportController error \(errorMessage)")
		connectionDelegate?.textController(self, didReceiveWebErrorMessage: errorMessage, lineNumber: lineNumber, columnNumber: columnNumber)
	}

	public func transportController(controller: TransportController, didDisconnectWithErrorMessage errorMessage: String?) {
		print("[TextController] TransportController disconnect \(errorMessage)")
		connectionDelegate?.textController(self, didDisconnectWithErrorMessage: errorMessage)
	}
}


extension TextController: DocumentControllerDelegate {
	public func documentControllerWillUpdateDocument(controller: DocumentController) {
		textStorage.beginEditing()
	}

	public func documentController(controller: DocumentController, didReplaceCharactersInPresentationStringInRange range: NSRange, withString string: String) {
		_layoutManager.removeFoldableRanges()
		_layoutManager.invalidFoldingRange = range
		_textStorage.actuallyReplaceCharactersInRange(range, withString: string)

		var foldableRanges = [NSRange]()
		controller.document.blocks.forEach { foldableRanges += stylesForBlock($0).1 }
		_layoutManager.addFoldableRanges(foldableRanges)

		guard let selection = presentationSelectedRange else { return }

		let length = (string as NSString).length
		let adjusted = SelectionController.adjust(selection: selection, replacementRange: range, replacementLength: length)
		setPresentationSelectedRange(adjusted, updateTextView: !adjusted.equals(selection))
	}

	public func documentController(controller: DocumentController, didInsertBlock block: BlockNode, atIndex index: Int) {
		annotationsController.insert(block: block, index: index)

		let (styles, _) = stylesForBlock(block)
		self.styles += styles

		var range = controller.document.presentationRange(block: block)
		if range.location > 0 {
			range.location -= 1
			range.length += 1
		}

		if range.max < (controller.document.presentationString as NSString).length {
			range.length += 1
		}

//		_textStorage.invalidRange(range)
		
		if let block = block as? Attachable, style = attachmentStyle(block: block) {
			self.styles.append(style)
		}

		if index == 0 {
			setNeedsTitleUpdate()
		}
	}

	public func documentController(controller: DocumentController, didRemoveBlock block: BlockNode, atIndex index: Int) {
		annotationsController.remove(block: block, index: index)

		if index == 0 {
			setNeedsTitleUpdate()
		}
	}

	public func documentControllerDidUpdateDocument(controller: DocumentController) {
		textStorage.endEditing()
		updateTitleIfNeeded(controller)
	}

	private func refreshAnnotations() {
		let blocks = currentDocument.blocks

		// Refresh models
		for (i, block) in blocks.enumerate() {
			guard let block = block as? Annotatable else { continue }
			annotationsController.update(block: block, index: i)
		}

		// Layout
		annotationsController.layoutAnnotations()
	}

	private func setNeedsTitleUpdate() {
		needsTitle = true
	}

	private func updateTitleIfNeeded(controller: DocumentController) {
		if !needsTitle {
			return
		}

		displayDelegate?.textController(self, didUpdateTitle: controller.document.title)
		needsTitle = false
	}
}


extension TextController: AnnotationsControllerDelegate {
	func annotationsController(annotationsController: AnnotationsController, willAddAnnotation annotation: Annotation) {
		annotationDelegate?.textController(self, willAddAnnotation: annotation)
	}

	func annotationsController(annotationsController: AnnotationsController, willRemoveAnnotation annotation: Annotation) {
		annotationDelegate?.textController(self, willRemoveAnnotation: annotation)
	}
}


extension TextController: CanvasTextStorageDelegate, NSTextStorageDelegate {
	public func canvasTextStorage(textStorage: CanvasTextStorage, willReplaceCharactersInRange range: NSRange, withString string: String) {
		// Create edit
		let presentationEdit = Edit(range: range, string: string)

		// Calculate edits
		let (edits, selection) = currentDocument.backingEdits(presentationEdit: presentationEdit, presentationSelection: presentationSelectedRange)

		// Apply the modified selection after the text storage finishes editing.
		nextSelection = selection

		// Apply local edits to the backing document
		documentController.apply(backingEdits: edits)

		// Send OT operations for edits
		submitOperations(edits: edits)
	}
	
	public func textStorage(textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
		if _textStorage.isEditing {
			return
		}

		updateUnfoldIfNeeded()

		// Update selection
		if let selection = nextSelection {
			setPresentationSelectedRange(selection, updateTextView: true)
			nextSelection = nil
		}

		dispatch_async(dispatch_get_main_queue()) { [weak self] in
			self?.refreshAnnotations()
		}
	}

	// Commit the edit to DocumentController and submit the operation to OT. This doesn't go through the text system so
	// things like markdown shortcuts and return completion don't run on this change. Ideally, this will only be used
	// by the text storage delegate or changes made to non-visible portions of the backing string (like block or
	// indentation changes).
	func edit(backingRange backingRange: NSRange, replacement: String) {
		documentController.replaceCharacters(inBackingRange: backingRange, withString: replacement)
		submitOperations(backingRange: backingRange, string: replacement)
	}
}


extension TextController: LayoutManagerDelegate {
	func layoutManager(layoutManager: NSLayoutManager, textContainerChangedGeometry textContainer: NSTextContainer) {
		layoutAttachments()
	}

	func layoutManagerDidUpdateFolding(layoutManager: NSLayoutManager) {
		// Trigger the text view to update its selection. Two Apple engineers recommended this.
		textStorage.beginEditing()
		textStorage.edited(.EditedCharacters, range: NSRange(location: 0, length: 0), changeInLength: 0)
		textStorage.endEditing()

		displayDelegate?.textControllerDidUpdateFolding(self)
	}
}
