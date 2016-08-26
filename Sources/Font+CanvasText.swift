//
//  TextStyle.swift
//  CanvasText
//
//  Created by Sam Soffes on 6/30/16.
//  Copyright © 2016 Canvas Labs, Inc. All rights reserved.
//

import X

public extension TextStyle {
	public func font(traits traits: FontDescriptorSymbolicTraits = [], minimumWeight: FontWeight? = nil) -> Font {
		var systemFont = Font.preferredFontForTextStyle(self)

//		// Apply minimum weight
//		if let minimumWeight = minimumWeight {
//			let currentWeight = (systemFont.fontDescriptor().objectForKey(UIFontDescriptorFaceAttribute) as? String).flatMap(FontWeight.init)
//			if weight.fontWeight > currentWeight?.fontWeight ?? 0 {
//				systemFont = UIFont.systemFontOfSize(systemFont.pointSize, weight: weight.fontWeight)
//			}
//		}

		return applySymbolicTraits(traits, toFont: systemFont, sanitize: false)
	}
	
	public func monoSpaceFont(traits traits: FontDescriptorSymbolicTraits = []) -> Font {
		let systemFont = Font.preferredFontForTextStyle(self)
		let monoSpaceFont = Font(name: "Menlo", size: systemFont.pointSize * 0.9)!
		return applySymbolicTraits(traits, toFont: monoSpaceFont)
	}
}


func applySymbolicTraits(traits: FontDescriptorSymbolicTraits, toFont font: Font, sanitize: Bool = true) -> Font {
//	var traits = traits
//
//	if sanitize && !traits.isEmpty {
//		var t = UIFontDescriptorSymbolicTraits()
//
//		if traits.contains(.TraitBold) {
//			t.insert(.TraitBold)
//		}
//
//		if traits.contains(.TraitItalic) {
//			t.insert(.TraitItalic)
//		}
//
//		traits = t
//	}
//
//	if traits.isEmpty {
//		return font
//	}
//
//	let fontDescriptor = font.fontDescriptor().fontDescriptorWithSymbolicTraits(traits)
//	return UIFont(descriptor: fontDescriptor, size: font.pointSize)
	return font
}
