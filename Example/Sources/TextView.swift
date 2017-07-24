//
//  TextView.swift
//  Example
//
//  Created by Sam Soffes on 3/8/16.
//  Copyright © 2016 Canvas Labs, Inc. All rights reserved.
//

import UIKit
import CanvasText

final class TextView: UITextView {
	// Only display the caret in the used rect (if available).
	override func caretRect(for position: UITextPosition) -> CGRect {
		var rect = super.caretRect(for: position)

		if let layoutManager = textContainer.layoutManager {
			layoutManager.ensureLayout(for: textContainer)

			let characterIndex = offset(from: beginningOfDocument, to: position)

			let height: CGFloat

			if characterIndex == 0 {
				// Hack for empty document
				height = 43.82015625
			} else {
				if characterIndex == textStorage.length {
					return rect
				}

				let glyphIndex = layoutManager.glyphIndexForCharacter(at: characterIndex)

				if UInt(glyphIndex) == UInt.max - 1 {
					return rect
				}

				height = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: nil).size.height
			}

			if height > 0 {
				rect.size.height = height
			}
		}

		return rect
	}

	// Omit empty width rect when drawing selection rects.
	override func selectionRects(for range: UITextRange) -> [Any] {
		let selectionRects = super.selectionRects(for: range)
		return selectionRects.filter({ selection in
			guard let selection = selection as? UITextSelectionRect else { return false }
			return selection.rect.size.width > 0
		})
	}
}


extension TextView: TextControllerAnnotationDelegate {
	func textController(_ textController: TextController, willAddAnnotation annotation: Annotation) {
		insertSubview(annotation.view, at: 0)
	}
	
	// FIXME:  Added the following function to just support the protocol
	func textController(_ textController: TextController, willRemoveAnnotation annotation: Annotation) {
	}
}
