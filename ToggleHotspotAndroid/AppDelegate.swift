//
//  AppDelegate.swift
//  ToggleHotspotAndroid
//
//  Created by Kosio on 22.04.19.
//  Copyright © 2019 Kosio. All rights reserved.
//

import Cocoa
import CoreBluetooth
import CoreWLAN
import SystemConfiguration

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSDraggingDestination, NSWindowDelegate {
    func updateRSSI(name: String, identifier: UUID, rssi: Int) {
        
    }

    override init() {
        super.init()
        //crossplatformDropModule.delegates.append(self)
    }

    @IBOutlet weak var statusMenu: NSMenu!
    var controller: ShareViewController? = nil
    
    let statusItem: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    func handleGetURLEvent(event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {}


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Handle incoming URLs
        //NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleGetURLEvent), forEventClass: kInternetEventClass, andEventID: kInternetEventClass)
        let icon = NSImage(named: "statusIcon")
        icon?.isTemplate = true // best for dark mode
        statusItem.button?.image = icon
        statusItem.menu = statusMenu
        self.statusItem.button?.window?.registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL, NSPasteboard.PasteboardType.URL, NSPasteboard.PasteboardType.string])
        self.statusItem.button?.window?.delegate = self
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        var item: Any = RHEAEntityResolver.resolve(sender.draggingPasteboard)

        if item is NSURL {
            print("URL")
        }
        if item is NSString {
            print("String")
            controller = ShareViewController(nibName: "ShareViewController", bundle: nil)
            let path = item as! NSString
            controller!.shareFile(path)
            var myWindow: NSWindow? = nil
            myWindow = NSWindow(contentViewController: controller!)
            myWindow?.makeKeyAndOrderFront(self)
            let vc = NSWindowController(window: myWindow)
            vc.showWindow(self)
        }
        print(item)
        return true
    }

    @IBAction func quitCliked(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }
    
    @IBAction func hotspotOnClick(_ sender: Any) {

    }
    @IBAction func hotspotOffClick(_ sender: Any) {

    }
}

