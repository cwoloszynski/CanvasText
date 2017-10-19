//
//  PersistenceController.swift
//  CanvasText
//
//  Created by Charlie Woloszynski on 10/14/17.
//  Copyright © 2017 Canvas Labs, Inc. All rights reserved.
//

import Foundation
import CanvasNative


class PersistenceController {
    
    private var id: String
    private var projectId: String
    private var timer: Timer?
    private var persistInterval: TimeInterval
    private let url: URL
    private var lastSave: Date?
    
    private let writeQueue: DispatchQueue
    
    static let rootDirectoryURL: URL = { () -> URL in
        let fileManager = FileManager.default
        guard let url = try? fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else {
            // This should only throw an error if the arguements are nonsensical
            // So, we simply abort the code if this happens
            fatalError()
        }
        if !fileManager.fileExists(atPath: url.path) {
            
        }
        return url
    }()
    
    static func projectDirectoryURL(_ projectId:String) -> URL {
        
        let url = PersistenceController.rootDirectoryURL.appendingPathComponent("project-\(projectId)")
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: false, attributes: [:])
            } catch let error {
                fatalError("Error creating directory for projectId: \(projectId) using url \(url.path).  Error \(error.localizedDescription)")
            }
        }
        return url
    }
    
    init(id: String, projectId: String) {
        self.id = id
        self.projectId = projectId
        self.timer = nil
        self.persistInterval = 60.seconds
        self.url = PersistenceController.projectDirectoryURL(projectId).appendingPathComponent("canvas-\(id)")
        self.writeQueue = DispatchQueue(label: "PersistenceController") // Serial by default
    }
    
    public func getContents() -> String {
        
        let contents: String
        
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
            return emptyContents
        }
        do {
            contents = try String(contentsOf: url, encoding: .utf8)
            if contents.isEmpty { return emptyContents }
        }
        catch let error {
            fatalError("Error reading url=\(url.path) error=\(error.localizedDescription)")
        }
        
        return contents
    }
    
    
    private var  emptyContents: String {
        get {
            let contents = "\(leadingNativePrefix)doc-heading\(trailingNativePrefix)Untitled"
            return contents
        }
    }
    public func updateContents(contents: String) {
       
        // If there is a pending timer, cancel it so we can start it again with new data
        if let timer = timer {
            timer.invalidate()
            self.timer = nil
            persistInterval = 15.seconds // If we cancel one, make sure the next interval is short
        }
        
        // Calculate when we want the next timer to go off.  The changes are pending for more than 5 minutes, create a timer with zero expiration
        var updateInterval = self.persistInterval
        
        if let lastSave = lastSave {
            let interval = Date().timeIntervalSince(lastSave)
            if interval > 5.minutes {
                updateInterval = 0.seconds
            }
        }
        
        // Create timer and implicitly schedule in run loop 
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: false) { _ in
            self.persist(contents: contents)
            self.lastSave = Date()
            self.persistInterval = 60.seconds // After saving, relax the interval again
        }
    }
    
    public func persistNow() {
        timer?.fire()
    }
    
    private func persist(contents: String) {
        // Make sure we don't enter this more than once at a time
        writeQueue.sync {
            print("writing contents to file")
            do {
                
                try contents.write(to: url, atomically: true, encoding: .utf8)
            }
            catch let error {
                fatalError("Error writing content to url: \(url.path) error: \(error.localizedDescription)")
            }
        }
    }
}

