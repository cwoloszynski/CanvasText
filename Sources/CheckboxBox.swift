//
//  CheckboxView.swift
//  Canvas
//
//  Created by Sam Soffes on 11/17/15.
//  Copyright © 2015 Canvas Labs, Inc. All rights reserved.
//

import UIKit
import CanvasNative

final class CheckboxView: UIButton, Annotation {

	// MARK: - Properties

	private let checklistItem: ChecklistItem

	var block: Annotatable {
		return checklistItem
	}

	var theme: Theme {
		didSet {
			backgroundColor = theme.backgroundColor
			setNeedsDisplay()
		}
	}


	// MARK: - Initializers

	init?(block: Annotatable, theme: Theme) {
		guard let checklistItem = block as? ChecklistItem else { return nil }
		self.checklistItem = checklistItem
		self.theme = theme

		super.init(frame: .zero)

		backgroundColor = theme.backgroundColor
		contentMode = .Redraw
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}


	// MARK: - UIView

	override func drawRect(rect: CGRect) {
		let rect = checkboxRectForBounds(bounds)

		if checklistItem.completion == .Complete {
			tintColor.setFill()
			UIBezierPath(roundedRect: rect, cornerRadius: 3).fill()

			let bundle = NSBundle(forClass: CheckboxView.self)
			if let checkmark = UIImage(named: "checkmark", inBundle: bundle, compatibleWithTraitCollection: nil) {
				Color.whiteColor().setFill()
				checkmark.drawAtPoint(CGPoint(x: rect.origin.x + (rect.width - checkmark.size.width) / 2, y: (bounds.height - checkmark.size.height) / 2))
			}
			return
		}

		theme.placeholderColor.setStroke()
		let path = UIBezierPath(roundedRect: CGRectInset(rect, 1, 1), cornerRadius: 3)
		path.lineWidth = 2
		path.stroke()
	}

	override func tintColorDidChange() {
		super.tintColorDidChange()
		setNeedsDisplay()
	}


	// MARK: - Private

	private func checkboxRectForBounds(bounds: CGRect) -> CGRect {
		let size: CGFloat = 16
		return CGRect(x: bounds.size.width - size - 4, y: floor((bounds.size.height - size) / 2) + 0.5, width: size, height: size)
	}
}