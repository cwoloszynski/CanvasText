//
//  AnnotationsController.swift
//  CanvasText
//
//  Created by Sam Soffes on 3/7/16.
//  Copyright © 2016 Canvas Labs, Inc. All rights reserved.
//

#if os(OSX)
	import AppKit
#else
	import UIKit
#endif

import CanvasNative
import X

protocol AnnotationsControllerDelegate: class {
	func annotationsController(annotationsController: AnnotationsController, willAddAnnotation annotation: Annotation)
	func annotationsController(annotationsController: AnnotationsController, willRemoveAnnotation annotation: Annotation)
}

final class AnnotationsController {

	// MARK: - Properties

	var enabled = true

	var theme: Theme {
		didSet {
			for annotation in annotations {
				annotation?.theme = theme
			}
		}
	}

	var textContainerInset: EdgeInsets = .zero {
		didSet {
			layoutAnnotations()
		}
	}

	var horizontalSizeClass: UserInterfaceSizeClass = .unspecified {
		didSet {
			for annotation in annotations {
				annotation?.horizontalSizeClass = horizontalSizeClass
			}
		}
	}

	weak var delegate: AnnotationsControllerDelegate?
	weak var textController: TextController?

	internal var annotations = [Annotation?]()


	// MARK: - Initializers

	init(theme: Theme) {
		self.theme = theme
	}


	// MARK: - Manipulating

	func insert(block: BlockNode, index: Int) {
		guard enabled, let block = block as? Annotatable, let annotation = annotationForBlock(block: block) else {
			annotations.insert(nil, at: index)
			return
		}

		annotations.insert(annotation, at: index)
        delegate?.annotationsController(annotationsController: self, willAddAnnotation: annotation)

		#if !os(OSX)
			// Add taps
			if annotation.view.isUserInteractionEnabled {
				let tap = TapGestureRecognizer(target: self, action: #selector(self.tap))
				annotation.view.addGestureRecognizer(tap)
			}
		#endif
	}

	func remove(block: BlockNode, index: Int) {
		guard enabled && index < annotations.count else { return }

		if let annotation = annotations[index] {
            delegate?.annotationsController(annotationsController: self, willRemoveAnnotation: annotation)
		}

		annotations[index]?.view.removeFromSuperview()
        _ = annotations.remove(at: index)
	}

	func update(block: BlockNode, index: Int) {
		guard enabled && index < annotations.count, let block = block as? Annotatable, let annotation = annotations[index] else { return }
		annotation.block = block
	}


	// MARK: - Layout

	func layoutAnnotations() {
		for annotation in annotations {
			guard let annotation = annotation else { continue }
			annotation.view.frame = rectForAnnotation(annotation: annotation)
		}
	}

	func rectForAnnotation(annotation: Annotation) -> CGRect {
		guard let textController = textController else { return .zero }

		let document = textController.currentDocument
		var presentationRange = document.presentationRange(block: annotation.block)

		// Add new line
		if presentationRange.max < (document.presentationString as NSString).length {
			presentationRange.length += 1
		}

		var rect: CGRect

		switch annotation.placement {
		case .FirstLeadingGutter:
			guard let firstRect = firstRectForPresentationRange(presentationRange: presentationRange) else { return .zero }
			rect = firstRect
			rect.size.width = rect.origin.x + 8
			rect.origin.x = -8
		case .ExpandedLeadingGutter:
			guard let rects = rectsForPresentationRange(presentationRange: presentationRange), let firstRect = rects.first else { return .zero }
			rect = rects.reduce(firstRect) { $0.union($1) }
			rect.size.width = rect.origin.x
			rect.origin.x = 0
		case .ExpandedBackground:
			guard let rects = rectsForPresentationRange(presentationRange: presentationRange), let firstRect = rects.first else { return .zero }
			rect = rects.reduce(firstRect) { $0.union($1) }
			rect.origin.x = 0
			rect.size.width = textController.textContainer.size.width
		}

		// Expand to the top of the next block if neccessary
		if annotation.placement.isExpanded, let positionable = annotation.block as? Positionable, !positionable.position.isBottom {
			if let index = document.indexOf(block: annotation.block), index < document.blocks.count - 1 {
				var nextRange = document.presentationRange(blockIndex: index + 1)
				nextRange.length = min(presentationRange.length + 1, textController.textStorage.length - nextRange.location)

				if let nextRect = firstRectForPresentationRange(presentationRange: nextRange) {
					if nextRect.minY > rect.maxY {
						rect.size.height = nextRect.minY - rect.minY
					}
				}
			}
		}

		let spacing = textController.blockSpacing(block: annotation.block)
		rect.origin.y -= spacing.paddingTop
		rect.size.height += spacing.paddingTop + spacing.paddingBottom

		rect.origin.x += textContainerInset.left
		rect.origin.y += textContainerInset.top

		return rect.integral
	}


	// MARK: - Private

	private func firstRectForPresentationRange(presentationRange: NSRange) -> CGRect? {
		guard let textController = textController else { return nil }

		let layoutManager = textController.layoutManager

		let glyphRange = layoutManager.glyphRange(forCharacterRange: presentationRange, actualCharacterRange: nil)
		layoutManager.ensureLayout(forGlyphRange: glyphRange)

		var rect: CGRect?
		layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, _, stop in
			rect = usedRect
			stop.pointee = true
		}
        
        // Look up the height of the previous line fragment so the next is consistent with the line above (NOT using the extraLineFragmentRect value)
        /* if rect == nil {
            let extendedRange = NSRange(location: glyphRange.location-1, length: glyphRange.length+1)
            layoutManager.enumerateLineFragments(forGlyphRange: extendedRange) { _, usedRect, _, _, _ in
                rect = usedRect
            }
        } */
        
        if rect == nil {
            rect = layoutManager.extraLineFragmentRect
        }
        
		return rect
	}

	private func rectsForPresentationRange(presentationRange: NSRange) -> [CGRect]? {
		guard let textController = textController else { return nil }

		let layoutManager = textController.layoutManager

		let glyphRange = layoutManager.glyphRange(forCharacterRange: presentationRange, actualCharacterRange: nil)
		layoutManager.ensureLayout(forGlyphRange: glyphRange)

		var rects = [CGRect]()
		layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { availableRect, usedRect, _, _, _ in
			rects.append(usedRect)
		}

		// Handle the last line
		if rects.isEmpty {
			rects.append(layoutManager.extraLineFragmentRect)
		}

		return rects
	}

	private func annotationForBlock(block: Annotatable) -> Annotation? {
		return block.annotation(theme: theme)
	}

	#if !os(OSX)
		@objc private func tap(sender: TapGestureRecognizer?) {
			guard let annotation = sender?.view as? CheckboxView,
				let block = annotation.block as? ChecklistItem
			else { return }

			let range = block.stateRange
			let replacement = block.state.opposite.string
			textController?.edit(backingRange: range, replacement: replacement)
		}
	#endif
}
