//
//  TextContainer.swift
//  CanvasText
//
//  Created by Sam Soffes on 2/2/16.
//  Copyright © 2016 Canvas Labs, Inc. All rights reserved.
//

#if os(OSX)
	import AppKit
#else
	import UIKit
#endif

import CanvasNative

class TextContainer: NSTextContainer {

	// MARK: - Properties

	weak var textController: TextController?


	// MARK: - Initializers

	override init(size: CGSize) {
		super.init(size: size)
		lineFragmentPadding = 0
	}

	required init(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}


	// MARK: - NSTextContainer

	override func lineFragmentRect(forProposedRect proposedRect: CGRect, at characterIndex: Int, writingDirection baseWritingDirection: NSWritingDirection, remaining remainingRect: UnsafeMutablePointer<CGRect>?) -> CGRect {
		var rect = proposedRect

		if let textController = textController, let block = textController.currentDocument.blockAt(presentationLocation: characterIndex) {
			if block is Attachable, let attachment = layoutManager?.textStorage?.attribute(NSAttachmentAttributeName, at: characterIndex, effectiveRange: nil) as? NSTextAttachment {
				let imageSize = attachment.bounds.size
				rect.origin.y = ceil(rect.origin.y)
				rect.origin.x += floor((size.width - imageSize.width) / 2)
				rect.size.width = imageSize.width
			} else {
				let blockSpacing = textController.blockSpacing(block: block)
				rect = blockSpacing.applyHorizontalPadding(rect)
			}
		}

		return super.lineFragmentRect(forProposedRect: rect, at: characterIndex, writingDirection: baseWritingDirection, remaining: remainingRect)
	}
}
