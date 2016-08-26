//
//  FontWeight+CanvasText.swift
//  CanvasText
//
//  Created by Sam Soffes on 8/26/16.
//  Copyright © 2016 Canvas Labs, Inc. All rights reserved.
//

import X

private let faces: [String: FontWeight] = [
	"UltraLight": .ultraLight,
	"Thin": .thin,
	"Light": .light,
	"Regular": .regular,
	"Medium": .medium,
	"SemiBold": .semibold,
	"Bold": .bold,
	"Heavy": .heavy,
	"Black": .black
]


extension FontWeight {
	init?(face: String) {
		guard let weight = faces[face] else { return nil }
		self = weight
	}
}
