//
//  ImagesController.swift
//  CanvasText
//
//  Created by Sam Soffes on 11/25/15.
//  Copyright © 2015 Canvas Labs, Inc. All rights reserved.
//

#if os(OSX)
	import AppKit
#else
	import UIKit
#endif

import Cache
import X

final class ImagesController: Themeable {
	
	// MARK: - Types
	
	typealias Completion = (_ id: String, _ image: Image?) -> Void
	
	
	// MARK: - Properties

	var theme: Theme
	let session: URLSession
	
	private var downloading = [String: [Completion]]()
	
	private let queue = DispatchQueue(label: "com.usecanvas.canvastext.imagescontroller", attributes: [])
	
	private let memoryCache = MemoryCache<Image>()
	private let imageCache: MultiCache<Image>
	private let placeholderCache = MemoryCache<Image>()
	
	
	// MARK: - Initializers
	
	init(theme: Theme, session: URLSession = URLSession.shared) {
		self.theme = theme
		self.session = session

		var caches = [AnyCache(memoryCache)]

		// Setup disk cache
		if let cachesDirectory = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first {
			let directory = (cachesDirectory as NSString).appendingPathComponent("com.usecanvas.canvas/Images") as String

			if let diskCache = DiskCache<Image>(directory: directory) {
				caches.append(AnyCache(diskCache))
			}
		}

		imageCache = MultiCache(caches: caches)
	}
	
	
	// MARK: - Accessing
	
	func fetchImage(id: String, url: URL?, size: CGSize, scale: CGFloat, completion: Completion) -> Image? {
		if let image = memoryCache[id] {
			return image
		}

		// Get cached image or download if there's a URL
		if let url = url {
			imageCache.get(key: id) { [weak self] image in
				if let image = image {
					DispatchQueue.main.async {
						completion(id, image)
					}
					return
				}

				self?.coordinate { [weak self] in
					// Already downloading
					if var array = self?.downloading[id] {
						array.append(completion)
						self?.downloading[id] = array
						return
					}

					// Start download
					self?.downloading[id] = [completion]

					let request = URLRequest(url: url)
					self?.session.downloadTask(with: request) { [weak self] location, _, _ in
						self?.loadImage(location: location, id: id)
					}.resume()
				}
			}
		}

		return placeholderImage(size: size, scale: scale)
	}
	
	
	// MARK: - Private
	
	private func coordinate(_ block: ()->()) {
		queue.sync(execute: block)
	}
	
	private func loadImage(location: URL?, id: String) {
		let data = location.flatMap { (try? Data(contentsOf: $0)) }
		let image = data.flatMap { Image(data: $0) }

		if let image = image {
			imageCache.set(key: id, value: image)
		}

		coordinate { [weak self] in
			if let image = image, let completions = self?.downloading[id] {
				for completion in completions {
					DispatchQueue.main.async {
						completion(id, image)
					}
				}
			}

			self?.downloading[id] = nil
		}
	}
	
	private func placeholderImage(size: CGSize, scale: CGFloat) -> Image? {
		let key = "\(size.width)x\(size.height)-\(scale)-\(theme.imagePlaceholderColor)-\(theme.imagePlaceholderBackgroundColor)"
		if let image = placeholderCache[key] {
			return image
		}

		let bundle = Bundle(for: ImagesController.self)
		guard let icon = Image(named: "PhotoLandscape", in: bundle) else { return nil }
		
		let rect = CGRect(x: 0, y: 0, width: size.width * scale, height: size.height * scale)

		let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
		guard let context = CGContext(
			data: nil,
			width: Int(rect.width),
			height: Int(rect.height),
			bitsPerComponent: 8,
			bytesPerRow: 0,
			space: CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: bitmapInfo.rawValue,
			releaseCallback: nil,
			releaseInfo: nil
		) else { return nil }

		// Background
		context.setFillColor(theme.imagePlaceholderBackgroundColor.cgColor)
		context.fill(rect)

		// Icon
		context.setFillColor(theme.imagePlaceholderColor.cgColor)
		let iconSize = CGSize(width: icon.size.width * scale, height: icon.size.height * scale)
		let iconFrame = CGRect(
			x: (rect.width - iconSize.width) / 2,
			y: (rect.height - iconSize.height) / 2,
			width: iconSize.width,
			height: iconSize.height
		)
		context.draw(icon.cgImage, in: iconFrame)



		let cgImage = context.makeImage()
		return cgImage.flatMap { NSImage(cgImage: $0, size: size) }
	}
}
