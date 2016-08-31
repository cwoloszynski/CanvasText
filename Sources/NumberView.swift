//
//  NumberView.swift
//  CanvasText
//
//  Created by Sam Soffes on 3/14/16.
//  Copyright © 2016 Canvas Labs, Inc. All rights reserved.
//

import X
import CanvasNative

final class NumberView: ViewType, Annotation {

	// MARK: - Private

	var block: Annotatable

	var theme: Theme {
		didSet {
			#if os(macOS)
				layer?.backgroundColor = theme.backgroundColor.cgColor
				needsDisplay = true
			#else
				backgroundColor = theme.backgroundColor
				setNeedsDisplay()
			#endif
		}
	}

	var horizontalSizeClass: UserInterfaceSizeClass = .unspecified


	// MARK: - Initializers

	init?(block: Annotatable, theme: Theme) {
		guard let orderedListItem = block as? OrderedListItem else { return nil }
		self.block = orderedListItem
		self.theme = theme

		super.init(frame: .zero)

		#if os(macOS)
			wantsLayer = true
			layer?.backgroundColor = theme.backgroundColor.cgColor
		#else
			isUserInteractionEnabled = false
			contentMode = .redraw
			backgroundColor = theme.backgroundColor
		#endif
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}


	// MARK: - View

	override func draw(_ rect: CGRect) {
		guard let block = block as? OrderedListItem else { return }

		let string = "\(block.number)." as NSString
		let attributes = [
			NSForegroundColorAttributeName: theme.orderedListItemNumberColor,
			NSFontAttributeName: FontTextStyle.body.font().fontWithMonospacedNumbers
		]

		#if os(macOS)
			let size = string.size(withAttributes: attributes)
		#else
			let size = string.size(attributes: attributes)
		#endif

		// TODO: It would be better if we could calculate this from the font
		let rect = CGRect(
			x: bounds.width - size.width - 4,
			y: ((bounds.height - size.height) / 2) - 1,
			width: size.width,
			height: size.height
		).integral

		string.draw(in: rect, withAttributes: attributes)
	}
}
