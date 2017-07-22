//
//  LayoutManager.swift
//  CanvasText
//
//  Created by Sam Soffes on 1/22/16.
//  Copyright © 2016 Canvas Labs, Inc. All rights reserved.
//

#if os(OSX)
	import AppKit
#else
	import UIKit
#endif

import CanvasNative
import X

protocol LayoutManagerDelegate: class {
	// Used so the TextController can relayout annotations and attachments if the text view changes its bounds (and
	// as a result changes the text container's geometry).
	func layoutManager(layoutManager: NSLayoutManager, textContainerChangedGeometry textContainer: NSTextContainer)
	func layoutManagerDidUpdateFolding(layoutManager: NSLayoutManager)
	func layoutManagerDidLayout(layoutManager: NSLayoutManager)
}

/// Custom layout manager to handle proper line spacing and folding. This must be its own delegate.
///
/// The TextController will manage updating `foldableRanges`. This will be all ranges that should be folded. It will
/// also update `unfoldedRange`. This is the range that should be excluded from folding. It will drive this value based
/// on the user's selection.
///
/// All ranges are presentation ranges.
class LayoutManager: NSLayoutManager {

	// MARK: - Properties

	weak var textController: TextController?
	weak var layoutDelegate: LayoutManagerDelegate?

	var unfoldedRange: NSRange? {
		didSet {
            let wasFolding = oldValue.flatMap( { (range: NSRange) -> Set<Int> in
                let indices = range.indices
                var oldFoldedIndices = foldedIndices
                oldFoldedIndices.subtract(indices)
                return oldFoldedIndices
            }) ?? foldedIndices
            
            let nowFolding = unfoldedRange.flatMap(  { (range: NSRange) -> Set<Int> in
                let indices = range.indices
                foldedIndices.subtract(indices)
                return foldedIndices
            }) ?? foldedIndices
			let updated = nowFolding.symmetricDifference(wasFolding)

			if updated.isEmpty {
				return
			}

			NSRange.ranges(indices: updated).forEach { range in
				invalidateGlyphs(forCharacterRange: range, changeInLength: 0, actualCharacterRange: nil)
			}

			needsUpdateTextContainer = true
		}
	}

	var invalidFoldingRange: NSRange?

	/// Folded ranges. Whenever this changes, it will trigger an invalidation of foldable glyphs.
	private var foldableRanges = [NSRange]() {
		didSet {
			var set = Set<Int>()
			foldableRanges.forEach { set.formUnion($0.indices) }
			foldedIndices = set
		}
	}

	/// If changes have been made to folding, we need to update the text container after it finishes its layout to apply
	/// the changes.
	private var needsUpdateTextContainer = false

	/// Set of indices that should be folded. Calculated from `foldableRanges`.
	fileprivate var foldedIndices = Set<Int>()
	
	// TODO: Get this from the theme and vary based on the block's font
	fileprivate let lineSpacing: CGFloat = 3


	// MARK: - Initializers

	override init() {
		super.init()
		allowsNonContiguousLayout = true
		delegate = self
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	
	// MARK: - NSLayoutManager

	override func textContainerChangedGeometry(_ container: NSTextContainer) {
		super.textContainerChangedGeometry(container)
		layoutDelegate?.layoutManager(layoutManager: self, textContainerChangedGeometry: container)
	}

	override var extraLineFragmentRect: CGRect {
		var rect = super.extraLineFragmentRect
		rect.size.height += lineSpacing
		return rect
	}

	override func processEditing(for textStorage: NSTextStorage, edited editMask: NSTextStorageEditActions, range: NSRange, changeInLength delta: Int, invalidatedRange: NSRange) {
		super.processEditing(for: textStorage, edited: editMask, range: range, changeInLength: delta, invalidatedRange: invalidatedRange)
		_ = invalidateFoldingIfNeeded()
	}


	// MARK: - Folding

	func addFoldableRanges(ranges: [NSRange]) {
		foldableRanges = (foldableRanges + ranges).sorted { $0.location < $1.location }
	}

	func removeFoldableRanges() {
		foldableRanges.removeAll()
	}

	func removeFoldableRanges(inRange range: NSRange) {
		foldableRanges = foldableRanges.filter { range.intersection($0) == nil }
	}

	func invalidateFoldableRanges(inRange invalidRange: NSRange) -> Bool {
		var invalidated = false

		for range in foldableRanges {
			if invalidRange.intersection(range) != nil {
				invalidateGlyphs(forCharacterRange: range, changeInLength: 0, actualCharacterRange: nil)
				invalidated = true
			}
		}

		return invalidated
	}

	func invalidateFoldingIfNeeded() -> Bool {
		guard let invalidRange = invalidFoldingRange else { return false }

		invalidFoldingRange = nil
		return invalidateFoldableRanges(inRange: invalidRange)
	}


	// MARK: - Private

	fileprivate func updateTextContainerIfNeeded() {
		if needsUpdateTextContainer {
			textContainers.forEach(ensureLayout)
			layoutDelegate?.layoutManagerDidUpdateFolding(layoutManager: self)
			needsUpdateTextContainer = false
		}

		layoutDelegate?.layoutManagerDidLayout(layoutManager: self)
	}

	fileprivate func blockNodeAt(glyphIndex: Int) -> BlockNode? {
		let characterIndex = characterIndexForGlyph(at: glyphIndex)
		return textController?.currentDocument.blockAt(presentationLocation: characterIndex)
	}
}


extension LayoutManager: NSLayoutManagerDelegate {
	// Mark folded characters as control characters so we can give them a zero width in
	// `layoutManager:shouldUseAction:forControlCharacterAtIndex:`.
	func layoutManager(_ layoutManager: NSLayoutManager, shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>, properties props: UnsafePointer<NSGlyphProperty>, characterIndexes: UnsafePointer<Int>, font: Font, forGlyphRange glyphRange: NSRange) -> Int {
		if foldedIndices.isEmpty {
			return 0
		}

		let properties = UnsafeMutablePointer<NSGlyphProperty>(mutating: props)

		var changed = false
		for i in 0..<glyphRange.length {
			let characterIndex = characterIndexes[i]

			// Skip selected characters
			if let selection = unfoldedRange, selection.contains(characterIndex) {
				continue
			}

			if foldedIndices.contains(characterIndex) {
				properties[i] = .controlCharacter
				changed = true
			}
		}

		if !changed {
			return 0
		}

		layoutManager.setGlyphs(glyphs, properties: properties, characterIndexes: characterIndexes, font: font, forGlyphRange: glyphRange)
		return glyphRange.length
	}

	// Folded characters should have a zero width
	func layoutManager(_ layoutManager: NSLayoutManager, shouldUse action: NSControlCharacterAction, forControlCharacterAt characterIndex: Int) -> NSControlCharacterAction {
		// Don't advance if it's a control character we changed
		if foldedIndices.contains(characterIndex) {
			return .zeroAdvancement
		}

		// Default action for things we didn't change
		return action
	}

	func layoutManager(_ layoutManager: NSLayoutManager, lineSpacingAfterGlyphAt glyphIndex: Int, withProposedLineFragmentRect rect: CGRect) -> CGFloat {
		return lineSpacing
	}

	// Adjust the top margin of lines based on their block type
	func layoutManager(_ layoutManager: NSLayoutManager, paragraphSpacingBeforeGlyphAt glyphIndex: Int, withProposedLineFragmentRect rect: CGRect) -> CGFloat {
		guard let textController = textController, let block = blockNodeAt(glyphIndex: glyphIndex) else { return 0 }

		// Apply the top margin if it's not the second node
		let blocks = textController.currentDocument.blocks
		let spacing = textController.blockSpacing(block: block)
		if spacing.marginTop > 0 && blocks.count >= 2 && block.range.location > blocks[1].range.location {
			return spacing.marginTop + spacing.paddingTop
		}

		return 0
	}

	// Adjust bottom margin of lines based on their block type
	func layoutManager(_ layoutManager: NSLayoutManager, paragraphSpacingAfterGlyphAt glyphIndex: Int, withProposedLineFragmentRect rect: CGRect) -> CGFloat {
		guard let textController = textController, let block = blockNodeAt(glyphIndex: glyphIndex) else { return 0 }
		let spacing = textController.blockSpacing(block: block)
		return spacing.marginBottom + spacing.paddingBottom
	}

	// If we've updated folding, we need to replace the layout manager in the text container. I'm all ears for a way to
	// avoid this.
	func layoutManager(_ layoutManager: NSLayoutManager, didCompleteLayoutFor textContainer: NSTextContainer?, atEnd layoutFinishedFlag: Bool) {
		updateTextContainerIfNeeded()
	}
}
