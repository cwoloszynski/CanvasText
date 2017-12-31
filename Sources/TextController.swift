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
/* Removing this since we don't use this anymore
public protocol TextControllerConnectionDelegate: class {
	func textController(_ textController: TextController, willConnectWithWebView webView: WKWebView)
	func textControllerDidConnect(_ textController: TextController)
	func textController(_ textController: TextController, didReceiveWebErrorMessage errorMessage: String?, lineNumber: UInt?, columnNumber: UInt?)
	func textController(_ textController: TextController, didDisconnectWithErrorMessage errorMessage: String?)
}
 */

public protocol TextControllerDisplayDelegate: class {
	func textController(_ textController: TextController, didUpdateSelectedRange selectedRange: NSRange)
	func textController(_ textController: TextController, didUpdateTitle title: String?)
	func textControllerWillProcessRemoteEdit(_ textController: TextController)
	func textControllerDidProcessRemoteEdit(_ textController: TextController)
	func textController(_ textController: TextController, URLForImage block: CanvasNative.Image) -> URL?
	func textControllerDidUpdateFolding(_ textController: TextController)
	func textControllerDidLayoutText(_ textController: TextController)
}

public protocol TextControllerAnnotationDelegate: class {
	func textController(_ textController: TextController, willAddAnnotation annotation: Annotation)
	func textController(_ textController: TextController, willRemoveAnnotation annotation: Annotation)
}


public final class TextController: NSObject {

	// MARK: - Properties

	// Removed the connectionDelegate since that is no longer used
    //public weak var connectionDelegate: TextControllerConnectionDelegate?
	public weak var displayDelegate: TextControllerDisplayDelegate?
	public weak var annotationDelegate: TextControllerAnnotationDelegate?

	let _textStorage = CanvasTextStorage()
	public var textStorage: NSTextStorage {
		return _textStorage
	}

	internal let _layoutManager = LayoutManager()
	public var layoutManager: NSLayoutManager {
		return _layoutManager
	}

	internal let _textContainer = TextContainer()
	public var textContainer: NSTextContainer {
		return _textContainer
	}

	public var presentationString: String {
		return textStorage.string
	}

    // public fileprivate(set) var presentationSelectedRange: NSRange?
    // FIXME: Not really sure that this should be public, but let's do 
    // there for now.
    public var presentationSelectedRange: NSRange?
    
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
		public var traitCollection = UITraitCollection(horizontalSizeClass: .unspecified) {
			didSet {
				traitCollectionDidChange(oldValue)
			}
		}
	#endif

	internal var transportController: TransportController?
	internal let annotationsController: AnnotationsController
	
	internal let imagesController: ImagesController

	internal let documentController = DocumentController()

    internal var persistenceController: PersistenceController
    
	public var currentDocument: Document {
		return documentController.document
	}

	// let serverURL: URL
	// let accessToken: String
	let projectUUID: String
	let canvasUUID: String

	internal var needsTitle = false
	internal var needsUnfoldUpdate = false
	internal var styles = [Style]()
	internal var invalidPresentationRange: NSRange?


	// MARK: - Initializers

	public init(projectUUID: String, canvasUUID: String, theme: Theme) {
		// self.serverURL = serverURL
		// self.accessToken = accessToken
		self.projectUUID = projectUUID
		self.canvasUUID = canvasUUID
		self.theme = theme
		imagesController = ImagesController(theme: theme)

		annotationsController = AnnotationsController(theme: theme)
        self.persistenceController = PersistenceController(uuid: canvasUUID, projectUuid: projectUUID)
        
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

    public func loadDocument() {
        // Initialize the document locally
        let backingString = persistenceController.getContents()
        let bounds = NSRange(location: 0, length: (currentDocument.backingString as NSString).length)
        
        setNeedsTitleUpdate()
        displayDelegate?.textControllerWillProcessRemoteEdit(self)
        documentController.replaceCharactersInBackingRange(bounds, withString: backingString)
        displayDelegate?.textControllerDidProcessRemoteEdit(self)
        
        invalidateFonts()
        
        applyStyles()
        
        annotationsController.layoutAnnotations()
    }

	// MARK: - OT

	public func connect() {
		/* if connectionDelegate == nil {
			print("[TextController] WARNING: connectionDelegate is nil. If you don't add the web view from textController:willConnectWithWebView: to a view, Operation Transport won't work as expected.")
		} */

		let transportController = TransportController(/* serverURL: serverURL, accessToken: accessToken, */ projectID: projectUUID, canvasID: canvasUUID)
		transportController.delegate = self
		transportController.connect()
		self.transportController = transportController
	}

	public func disconnect(withReason reason: String?) {
		transportController?.disconnect(withReason: reason)
		transportController = nil
	}
	
    public func saveDataOnViewWillDisappear() {
        persistenceController.persistNow()
    }
	
	// MARK: - Traits

	#if !os(OSX)
		public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
			layoutAttachments()
			annotationsController.horizontalSizeClass = traitCollection.horizontalSizeClass
		}
	#endif

	public func setTintColor(_ tintColor: Color) {
		guard tintColor != theme.tintColor else { return }

		theme.tintColor = tintColor

		// Update links
		var styles = [Style]()
		for block in currentDocument.blocks {
			guard let container = block as? NodeContainer else { continue }
			let attributes = theme.attributes(block: block)
			styles += stylesForSpans(container.subnodes, parentAttributes: attributes, onlyTintable: true).0
		}

		if !styles.isEmpty {
			self.styles += styles
			applyStyles()
		}
	}


	// MARK: - Selection

	// Update from Text View
	public func setPresentationSelectedRange(_ range: NSRange?) {
		setPresentationSelectedRange(range, updateTextView: false)
	}

	// Update from Text Controller
	public func setPresentationSelectedRange(_ range: NSRange?, updateTextView: Bool) {
        
		presentationSelectedRange = range
        
		needsUnfoldUpdate = true
		DispatchQueue.main.async { [weak self] in
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
	
	public func invalidateFonts() {
		styles.removeAll()
		
		for block in currentDocument.blocks {
			let (blockStyles, _) = stylesForBlock(block)
			styles += blockStyles
		}
		
		applyStyles()
		annotationsController.layoutAnnotations()
	}


	// MARK: - Layout

	func blockSpacing(block: BlockNode) -> BlockSpacing {
		#if os(OSX)
			let horizontalSizeClass = UserInterfaceSizeClass.Unspecified
		#else
			let horizontalSizeClass = traitCollection.horizontalSizeClass
		#endif
		return theme.blockSpacing(block: block, horizontalSizeClass: horizontalSizeClass)
	}

	fileprivate func invalidatePresentationRange(_ range: NSRange) {
		invalidPresentationRange = invalidPresentationRange.flatMap { $0.union(range) } ?? range
	}
	
	fileprivate func invalidateLayoutIfNeeded() {
		guard var range = invalidPresentationRange else { return }
		
		if range.max > textStorage.length {
			print("WARNING: Invalid range is too long. Adjusting.")
			range.length = min(textStorage.length - range.location, range.length)
		}
		
		layoutManager.ensureGlyphs(forCharacterRange: range)
		layoutManager.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
		
		applyStyles()
		refreshAnnotations()
		
		self.invalidPresentationRange = nil
	}

	fileprivate func layoutAttachments() {
		var styles = [Style]()
		
		for block in currentDocument.blocks {
			guard let block = block as? Attachable,
				let style = attachmentStyle(block: block)
				else { continue }
			
			styles.append(style)
		}
		
		self.styles += styles
		applyStyles()
	}


	// MARK: - Private

	fileprivate func updateUnfoldIfNeeded() {
		guard needsUnfoldUpdate else { return }

        let unfoldedRange = presentationSelectedRange.flatMap {
            unfoldableRange(presentationSelectedRange: $0)
        }
		_layoutManager.unfoldedRange = unfoldedRange
		needsUnfoldUpdate = false
	}

	/// Expand selection to the entire node.
	///
	/// - parameter displaySelection: Range of the selected text in the display text
	/// - returns: Optional presentation range of the expanded selection
	fileprivate func unfoldableRange(presentationSelectedRange: NSRange) -> NSRange? {
            // FIXME:  I took out this range manipulation since I cannot figure out what it is targeted to do (but back up the selection to at least two characters, except at the start of the document
            // range.location = max(0, range.location - 1)
			// range.length += (presentationSelectedRange.location - range.location) + 1

        // Replacing the function call in the initialization of the selectedRange
         let backingRanges = currentDocument.backingRanges(presentationRange: presentationSelectedRange)
         let selectedRange: NSRange = backingRanges.reduce(backingRanges[0]) { $0.union($1) }

		let selectedNodes = currentDocument.nodesIn(backingRange: selectedRange)
        let foldableNodes = selectedNodes.filter { $0 is Foldable }
		var foldableRanges = ArraySlice<NSRange>(foldableNodes.map {
            currentDocument.presentationRange(backingRange: $0.range)
        })

		guard var range = foldableRanges.popFirst() else { return nil }

		for r in foldableRanges {
			range = range.union(r)
		}

		return range
	}
	
	// Returns an array of styles and an array of foldable ranges
	fileprivate func stylesForBlock(_ block: BlockNode) -> ([Style], [NSRange]) {
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

		// Foldable attributes
		if let foldable = block as? Foldable {
			let foldableAttributes = theme.foldingAttributes(parentAttributes: attributes)

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
			let (innerStyles, innerFoldableRanges) = stylesForSpans(container.subnodes, parentAttributes: attributes)
			styles += innerStyles
			foldableRanges += innerFoldableRanges
		}
        
        if let attachment = block as? Attachable {
            if let style = attachmentStyle(block: attachment) {
                styles.append(style)
            }
        }

		return (styles, foldableRanges)
	}

	// Returns an array of styles and an array of foldable ranges
	fileprivate func stylesForSpans(_ spans: [SpanNode], parentAttributes: Attributes, onlyTintable: Bool = false) -> ([Style], [NSRange]) {
		var styles = [Style]()
		var foldableRanges = [NSRange]()

		for span in spans {
			guard let attributes = theme.attributes(span: span, parentAttributes: parentAttributes) else { continue }

			if (onlyTintable && span is Link) || !onlyTintable {
				let style = Style(
					range: currentDocument.presentationRange(backingRange: span.visibleRange),
					attributes: attributes
				)
				styles.append(style)

				let foldableAttributes = theme.foldingAttributes(parentAttributes: attributes)

				// Foldable attributes
				if let foldable = span as? Foldable {
					// Forward the background color
					var attrs = foldableAttributes
                    attrs[NSAttributedStringKey.backgroundColor] = attributes[NSAttributedStringKey.backgroundColor]

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
                    attrs[NSAttributedStringKey.foregroundColor] = theme.linkURLColor

					styles.append(Style(range: currentDocument.presentationRange(backingRange: link.urlRange), attributes: attrs))

					if let title = link.title {
						styles.append(Style(range: currentDocument.presentationRange(backingRange: title.textRange), attributes: attrs))
					}
				}
			}

			if let container = span as? NodeContainer {
				let (innerStyles, innerFoldableRanges) = stylesForSpans(container.subnodes, parentAttributes: attributes)
				styles += innerStyles
				foldableRanges += innerFoldableRanges
			}
		}

		return (styles, foldableRanges)
	}

	fileprivate func submitOperations(backingRange: NSRange, string: String) {
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
	
	fileprivate func attachmentStyle(block: Attachable) -> Style? {
		let attachment: NSTextAttachment
		
		// Horizontal rule
		if block is HorizontalRule {
			guard let image = HorizontalRuleAttachment.image(theme: theme) else { return nil }
			
			attachment = NSTextAttachment()
			attachment.image = image
			attachment.bounds = CGRect(x: 0, y: 0, width: textContainer.size.width, height: HorizontalRuleAttachment.height)
		}

		// Image
		else if let block = block as? CanvasNative.Image {
			let url = displayDelegate?.textController(self, URLForImage: block) ?? block.url

			#if os(OSX)
				// TODO: Use real scale
				let scale: CGFloat = 2
			#else
				let scale = traitCollection.displayScale
			#endif

			var size = attachmentSize(imageSize: block.size)
			let image = imagesController.fetchImage(
				id: block.identifier,
				url: url as NSURL?,
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
            NSAttributedStringKey.attachment: attachment
		])
	}
	
	fileprivate func attachmentSize(imageSize input: CGSize?) -> CGSize {
		let imageSize = input ?? CGSize(width: floor(textContainer.size.width), height: 300)
		let width = min(floor(textContainer.size.width), imageSize.width)
		var size = imageSize
		
		size.height = floor(width * size.height / size.width)
		size.width = width
		
		return size
	}
	
	fileprivate func blockForImageID(_ ID: String) -> CanvasNative.Image? {
		for block in currentDocument.blocks {
			if let image = block as? CanvasNative.Image, image.identifier == ID {
				return image
			}
		}
		
		return nil
	}
	
	fileprivate func updateImageAttachment(ID: String, image: X.Image?) {
		guard let image = image, let block = blockForImageID(ID) else { return }
		
		let attachment = NSTextAttachment()
		attachment.image = image
		attachment.bounds = CGRect(origin: .zero, size: attachmentSize(imageSize: image.size))
		
		let range = currentDocument.presentationRange(block: block)
		let style = Style(range: range, attributes: [
            NSAttributedStringKey.attachment: attachment
		])
		
		styles.append(style)
		applyStyles()
		annotationsController.layoutAnnotations()
	}
}


extension TextController: TransportControllerDelegate {

    // This probably needs to be replaced with a didConnect() and drop the web view stuff
	public func transportController(_ controller: TransportController, willConnectWithWebView webView: WKWebView) {
		// connectionDelegate?.textController(self, willConnectWithWebView: webView)
	}

	public func transportController(_ controller: TransportController, didReceiveSnapshot text: String) {
		let bounds = NSRange(location: 0, length: (currentDocument.backingString as NSString).length)

		// Ensure we have a valid document
		var string = text
		if string.isEmpty {
            string = DocumentTitle.nativeRepresentation("", uuid:"1234")  // Submit blank title name to remote server
			submitOperations(backingRange: bounds, string: string)
		}

		setNeedsTitleUpdate()
		displayDelegate?.textControllerWillProcessRemoteEdit(self)
		documentController.replaceCharactersInBackingRange(bounds, withString: string)
        persistenceController.updateContents(contents: currentDocument.backingString)
		// connectionDelegate?.textControllerDidConnect(self)
		displayDelegate?.textControllerDidProcessRemoteEdit(self)
		
		applyStyles()
		annotationsController.layoutAnnotations()
	}
    
    public func transportController(_ controller: TransportController, didReceiveOperation operation: OperationalTransformation.Operation) {
        
		displayDelegate?.textControllerWillProcessRemoteEdit(self)

		switch operation {
		case .insert(let location, let string):
			let range = NSRange(location: Int(location), length: 0)
			documentController.replaceCharactersInBackingRange(range, withString: string)

		case .remove(let location, let length):
			let range = NSRange(location: Int(location), length: Int(length))
			documentController.replaceCharactersInBackingRange(range, withString: "")
		}

        persistenceController.updateContents(contents: currentDocument.backingString)
		displayDelegate?.textControllerDidProcessRemoteEdit(self)
	} 

	public func transportController(_ controller: TransportController, didReceiveWebErrorMessage errorMessage: String?, lineNumber: UInt?, columnNumber: UInt?) {
		print("[TextController] TransportController error \(String(describing: errorMessage))")
		// connectionDelegate?.textController(self, didReceiveWebErrorMessage: errorMessage, lineNumber: lineNumber, columnNumber: columnNumber)
	}

	public func transportController(_ controller: TransportController, didDisconnectWithErrorMessage errorMessage: String?) {
		print("[TextController] TransportController disconnect \(String(describing: errorMessage))")
		// connectionDelegate?.textController(self, didDisconnectWithErrorMessage: errorMessage)
	}
}


extension TextController: DocumentControllerDelegate {
	public func documentControllerWillUpdateDocument(_ controller: DocumentController) {
		textStorage.beginEditing()
	}

	public func documentController(_ controller: DocumentController, didReplaceCharactersInPresentationStringInRange range: NSRange, withString string: String) {
		_layoutManager.removeFoldableRanges()
		_layoutManager.invalidFoldingRange = range
		_textStorage.actuallyReplaceCharacters(in: range, with: string)
		
		// Calculate the line range
        var changedRange = range
        changedRange.length = string.utf16.count
		let text = textStorage.string as NSString
        var lineRange = text.lineRange(for: changedRange)
        
        // Include the line before, if possible to ajdust for any formatting changes
        if lineRange.location > 0 { lineRange.location -= 1; lineRange.length += 1 }
        
        let finalRange = text.lineRange(for: lineRange) // Extend to full lines
        
		invalidatePresentationRange(finalRange)

		var foldableRanges = [NSRange]()
		controller.document.blocks.forEach { foldableRanges += stylesForBlock($0).1 }
		_layoutManager.addFoldableRanges(ranges: foldableRanges)

		guard let selection = presentationSelectedRange else { return }

		let length = (string as NSString).length
		let adjusted = SelectionController.adjust(selection: selection, replacementRange: range, replacementLength: length)
		setPresentationSelectedRange(adjusted, updateTextView: !adjusted.equals(selection))
	}

	public func documentController(_ controller: DocumentController, didInsertBlock block: BlockNode, atIndex index: Int) {
		annotationsController.insert(block: block, index: index)

		let (blockStyles, _) = stylesForBlock(block)
		styles += blockStyles

        // include the previous line, if there is one
		var range = controller.document.presentationRange(block: block)
		if range.location > 0 {
			range.location -= 1
			range.length += 1
		}

        // inclue the subsequent line, if there is one
        
		if range.max < controller.document.presentationString.utf16.count {
			range.length += 1
		}
        let text = controller.document.presentationString as NSString
        let finalRange = text.lineRange(for: range)
        
		invalidatePresentationRange(finalRange)
		
		if let block = block as? Attachable, let style = attachmentStyle(block: block) {
			styles.append(style)
		}

		if index == 0 {
			setNeedsTitleUpdate()
		}
	}

	public func documentController(_ controller: DocumentController, didRemoveBlock block: BlockNode, atIndex index: Int) {
		annotationsController.remove(block: block, index: index)

        // Make sure the invalidatedRange is truncated if we remove some if it..
        if let range = invalidPresentationRange, range.max > controller.document.presentationString.utf16.count {
            let length = controller.document.presentationString.utf16.count - range.location
            invalidPresentationRange = NSRange(location: range.location, length: length)
            
        }
		if index == 0 {
			setNeedsTitleUpdate()
		}
	}

	public func documentControllerDidUpdateDocument(_ controller: DocumentController) {
		textStorage.endEditing()
		updateTitleIfNeeded(controller)
        persistenceController.updateContents(contents: currentDocument.backingString)
		
        // The old design in the code seemed to create styles
        // dynamically.  However, with markdown processing,
        // the style list would seem to get out of sync
        // and we'd get errors when applying the styles.
        // Those are applied when the 'invalidateLayoutIfNeeded()
        // is called.
        //
        // So, instead we remove all the styles and then
        // compute the styles for all the blocks in the document
        // for now.  This may slow down the operation for large
        // documents but let's get this working first and
        // then focus on optimizing that later.
        
        styles.removeAll()
        
        for block in currentDocument.blocks {
            let (blockStyles, _) = stylesForBlock(block)
            styles += blockStyles
        }
        
		DispatchQueue.main.async { [weak self] in
			self?.invalidateLayoutIfNeeded()
		}
	}
    
	fileprivate func refreshAnnotations() {
		let blocks = currentDocument.blocks

		// Refresh models
		for (i, block) in blocks.enumerated() {
			guard let block = block as? Annotatable else { continue }
			annotationsController.update(block: block, index: i)
		}

		// Layout
		annotationsController.layoutAnnotations()
	}

	fileprivate func setNeedsTitleUpdate() {
		needsTitle = true
	}

	fileprivate func updateTitleIfNeeded(_ controller: DocumentController) {
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
	public func canvasTextStorage(_ textStorage: CanvasTextStorage, willReplaceCharactersIn range: NSRange, with string: String) {
        
		let document = currentDocument
		var replacement = string
        var presentationRange = range
        
        // If we are deleting (range of one or more characters being replaced), we need to adjust the use of the rang
        let isReplacing = (presentationRange.length > 0)

		let backingRanges = document.backingRanges(presentationRange: presentationRange)
		var backingRange = backingRanges[0]
         
         if !isReplacing && backingRange.length > 0 { // If this is an insertion, we skip the end of the range from the backingRange calculation.
            backingRange.location += backingRange.length
            backingRange.length = 0
        } 
        
		// Return completion, update the backing range and replacement
        // to reflect what we want to consider as having been typed
        //
		if string == "\n" {
			let currentBlock = document.blockAt(backingLocation: backingRange.location)

			// Check inside paragraphs
			if let block = currentBlock as? Paragraph {
				let string = document.presentationString(block: block)

				// Image
				if let url = URL(string: string), url.isImageURL {
					backingRange = block.range
					replacement = Image.nativeRepresentation(URL: url) + "\n"
				}

				// Code block
				else if string.hasPrefix("```") {
                    let baseLanguage = (string as NSString).substring(from: 3) as NSString
                        
                    let language = baseLanguage.trimmingCharacters(in: .whitespaces)
					backingRange = block.range
					replacement = CodeBlock.nativeRepresentation(language: language)
				}

				// Horizontal rule
				else if string == "---" {
					backingRange = block.range
					replacement = HorizontalRule.nativeRepresentation() + "\n"
				}
        
                else if string.hasPrefix("-[ ]") {
                    let itemText = string.suffix(4)
                    backingRange = block.range
                    replacement = ChecklistItem.nativeRepresentation(indentation: .zero, state: .unchecked) + itemText + "\n"
                }
                
                else if string.hasPrefix("-[x]") {
                    let itemText = string.suffix(4)
                    backingRange = block.range
                    replacement = ChecklistItem.nativeRepresentation(indentation: .zero, state: .checked) + itemText + "\n"
                }
			}

			// Continue the previous node type on return when appropriate
			else if let block = currentBlock as? ReturnCompletable {
				// Bust out of completion of this type of block
				if block.visibleRange.length == 0 {
					backingRange = block.range
					replacement = ""
                    // The annotations for this block (and the block itself) will get removed in
                    // the processChange() after the computeChangeReplacingCharacters() call so no
                    // other action required here.
                    
					// Keep selection in place
					setPresentationSelectedRange(presentationSelectedRange, updateTextView: true)
				} else {
					// Complete the node as another of the same, including indent level.
					if let block = block as? NativePrefixable {
						replacement += (document.backingString as NSString).substring(with: block.nativePrefixRange)

						// Make checkboxes unchecked by default
						if let checklist = block as? ChecklistItem, checklist.state == .checked {
							replacement = replacement.replacingOccurrences(of: "-[x] ", with: "-[ ] ")
						}
					}
				}
			}
		}

		// Handle inserts around attachments
		else if !replacement.isEmpty {
			if let block = document.blockAt(presentationLocation: range.location) as? Attachable {
				let presentation = document.presentationRange(block: block)

				// Add a new line before edits immediately following an Attachable
				if range.location == presentation.max {
					replacement = "\n" + replacement
				}

				// Add a new line after edits immediately before an Attachable {
				else if (range.location == presentationRange.location) && (range.location > 0) {
					presentationRange.location -= 1
					
					// FIXME: Update to support inline markers
					backingRange = document.backingRanges(presentationRange: presentationRange)[0]
					replacement = "\n" + replacement
				}
			}
        } else if replacement.isEmpty {
            
            // All of these changes should be handled in 'processTransformations()' and not here.
            // Need to handle deletions of \n that need to revert a change of a markdown text (e.g. horizontal rule)
            // When we 'eat' a newline and cause a horizontal rule to no longer be terminated,
            // we need to expand the replacement to remove the rest of that horizontal rule and inject a '---' instead.
            /* let removedString = (document.backingString as NSString).substring(with: backingRange)
            if removedString == "\n" {
                if let block = document.blockAt(presentationLocation: presentationRange.location), let index = document.indexOf(block: block), index>0 {
                    let preceeding = document.blocks[index-1]
                    if let _ = block as? HorizontalRule, let _ = preceeding as? HorizontalRule {
                        let expandedCount = 2*HorizontalRule.nativeRepresentation().utf16.count
                        backingRange.location -= expandedCount
                        backingRange.length += expandedCount
                        replacement = "------"
                    } else if let _ = preceeding as? HorizontalRule {
                        let expandedCount = HorizontalRule.nativeRepresentation().utf16.count
                        backingRange.location -= expandedCount
                        backingRange.length += expandedCount
                        replacement = "---"
                    }
                }
            } else if removedString == HorizontalRule.nativeRepresentation() {
                if document.backingString.utf16.count > backingRange.max {
                    backingRange.length += 1 // Include the \n newline for removal (expand selection forward in this instance)
                }
            } */
        }
            
            
        // At this point in processing the edits, the changes to the backing string
        // should leave us with a backing store that represents the
        // user's intents.  We need to execute those and then
        // update the presentation string (and backing string) to reflect the
        // knock-on effects of these edits.
        
		edit(backingRange: backingRange, replacement: replacement)

		// Remove other backing ranges beyond the first one in the extended range selected.
		if backingRanges.count > 1 {
			var ranges = backingRanges
			ranges.remove(at: 0)

			var offset = replacement.isEmpty ? backingRange.length : 0

			for r in ranges {
				if backingRange.intersection(r) != nil {
					continue
				}

				var range = r
				range.location -= offset
				edit(backingRange: range, replacement: "")

				offset += range.length
			}
		}
        // Update backing length after replacement
		backingRange.length = (replacement as NSString).length
		presentationRange = document.presentationRange(backingRange: backingRange)
        
        // Process any markdown transformations that this editing may have triggered
		processTransformations(presentationRange)
        
		// Handle selection when there is a user-driven replacement. This could definitely be cleaner.
		DispatchQueue.main.async { [weak self] in
			if var selection = self?.presentationSelectedRange, selection.length > 0 {
				selection.location += (string as NSString).length
				selection.length = 0
				self?.setPresentationSelectedRange(selection, updateTextView: true)
			}
		}
	}
	
	public func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
		if _textStorage.isEditing {
			return
		}

		updateUnfoldIfNeeded()

		DispatchQueue.main.async { [weak self] in
			self?.invalidateLayoutIfNeeded()
		}
	}

	// Commit the edit to DocumentController and submit the operation to OT. This doesn't go through the text system so
	// things like markdown shortcuts and return completion don't run on this change. Ideally, this will only be used
	// by the text storage delegate or changes made to non-visible portions of the backing string (like block or
	// indentation changes).
	func edit(backingRange: NSRange, replacement: String) {
        documentController.replaceCharactersInBackingRange(backingRange, withString: replacement)
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
		textStorage.edited(.editedCharacters, range: NSRange(location: 0, length: 0), changeInLength: 0)
		textStorage.endEditing()

		displayDelegate?.textControllerDidUpdateFolding(self)
	}

	func layoutManagerDidLayout(layoutManager: NSLayoutManager) {
		displayDelegate?.textControllerDidLayoutText(self)
	}
}
