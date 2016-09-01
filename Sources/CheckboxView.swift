//
//  CheckboxView.swift
//  Canvas
//
//  Created by Sam Soffes on 11/17/15.
//  Copyright © 2015 Canvas Labs, Inc. All rights reserved.
//

import X
import CanvasNative

final class CheckboxView: ViewType, Annotation {

	// MARK: - Properties

	var block: Annotatable {
		didSet {
			guard let old = oldValue as? ChecklistItem,
				let new = block as? ChecklistItem
			else { return }

			if old.state != new.state {
				#if os(macOS)
					needsDisplay = true
				#else
					setNeedsDisplay()
				#endif
			}
		}
	}

	var theme: Theme {
		didSet {
			#if os(macOS)
				layer?.backgroundColor = theme.backgroundColor.cgColor
				needsDisplay = true
			#else
				backgroundColor = theme.backgroundColor
				tintColor = theme.tintColor
				setNeedsDisplay()
			#endif
		}
	}

	#if os(macOS)
		var tintColor: Color {
			return theme.tintColor
		}
	#endif

	var horizontalSizeClass: UserInterfaceSizeClass = .unspecified


	// MARK: - Initializers

	init?(block: Annotatable, theme: Theme) {
		guard let checklistItem = block as? ChecklistItem else { return nil }
		self.block = checklistItem
		self.theme = theme

		super.init(frame: .zero)

		#if os(macOS)
			wantsLayer = true
			layer?.backgroundColor = theme.backgroundColor.cgColor

			let area = NSTrackingArea(rect: bounds, options: [.activeInActiveApp, .mouseMoved, .inVisibleRect], owner: self, userInfo: nil)
			addTrackingArea(area)
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
		guard let checklistItem = block as? ChecklistItem else { return }

		let lineWidth: CGFloat = 2
		let rect = checkboxRect(bounds: bounds).insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
		let cornerRadius = floor(rect.height / 2)

		if checklistItem.state == .checked {
			tintColor.setFill()

			#if os(macOS)
				NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius).fill()
			#else
				UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).fill()
			#endif

			let bundle = Bundle(for: CheckboxView.self)
			if let checkmark = Image(named: "CheckmarkSmall", in: bundle) {
				let checkmarkRect = CGRect(
					x: rect.origin.x + (rect.width - checkmark.size.width) / 2,
					y: rect.origin.y + (rect.height - checkmark.size.height) / 2,
					width: checkmark.size.width,
					height: checkmark.size.height
				)

				#if os(macOS)
					checkmark.lockFocus()
					theme.backgroundColor.set()
					NSRectFillUsingOperation(CGRect(origin: .zero, size: checkmark.size), NSCompositeSourceAtop)
					checkmark.unlockFocus()
				#else
					theme.backgroundColor.setFill()
				#endif

				checkmark.draw(in: checkmarkRect)
			}
			return
		}

		theme.uncheckedCheckboxColor.setStroke()
		#if os(macOS)
			let path = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: cornerRadius, yRadius: cornerRadius)
		#else
			let path = UIBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: cornerRadius)
		#endif
		path.lineWidth = lineWidth
		path.stroke()
	}

	#if os(iOS)
		override func tintColorDidChange() {
			super.tintColorDidChange()
			setNeedsDisplay()
		}
	#endif

	#if os(macOS)
		override func mouseMoved(with event: NSEvent) {
			NSCursor.pointingHand().set()
		}
	#endif


	// MARK: - Private

	private func checkboxRect(bounds: CGRect) -> CGRect {
		let size = bounds.height

		return CGRect(
			x: bounds.size.width - size - 4,
			y: floor((bounds.size.height - size) / 2) - 1,
			width: size,
			height: size
		)
	}
}
