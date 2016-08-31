//
//  ImageAttachmentCell.swift
//  CanvasText
//
//  Created by Sam Soffes on 8/31/16.
//  Copyright © 2016 Canvas Labs, Inc. All rights reserved.
//

import AppKit

final class ImageAttachmentCell: NSTextAttachmentCell {

	// MARK: - Properties

	let size: CGSize


	// MARK: - Initializers

	init(image: NSImage, size: CGSize) {
		self.size = size
		super.init(imageCell: image)
	}
	
	required init(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}


	// MARK: - NSTextAttachmentCell

	override func cellSize() -> NSSize {
		return size
	}

	override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
		controlView?.lockFocus()

		let rect = cellFrame
		image?.draw(in: rect)

		controlView?.unlockFocus()
	}
}
