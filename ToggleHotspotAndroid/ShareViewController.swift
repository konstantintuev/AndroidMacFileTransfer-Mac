//
//  ShareViewController.swift
//  CrossplatformDrop
//
//  Created by Kosio on 28.04.19.
//  Copyright © 2019 Kosio. All rights reserved.
//

import Cocoa

extension NSOpenPanel {
    var selectUrl: URL? {
        title = "Select File"
        allowsMultipleSelection = false
        canChooseDirectories = false
        canChooseFiles = true
        canCreateDirectories = false
        //allowedFileTypes = ["jpg","png","pdf","pct", "bmp", "tiff"]  // to allow only images, just comment out this line to allow any file type to be selected
        return runModal() == .OK ? urls.first : nil
    }
}

class ShareViewController: NSViewController, CrossplatformDropModuleDelegate, NSTableViewDataSource {

    @IBOutlet weak var bigLabel: NSTextField!
    @IBOutlet weak var sendBtn: NSButton!
    @IBOutlet weak var deviceTable: NSTableView!
    @IBOutlet weak var cancelBtn: NSButton!
    
    @IBOutlet weak var progressBar: NSProgressIndicator!
    @IBOutlet weak var tableViewParent: NSScrollView!
    var crossplatformDropModule = CrossplatformDropModule.shared
    var tableViewData: [[NSUserInterfaceItemIdentifier : String]] = []

    var devicePosition: [UUID : Int] = [:]

    override var nibName: NSNib.Name? {
        return NSNib.Name("ShareViewController")
    }

    func foundDevice(name: String, identifier: UUID, rssi: Int) {
        NSLog("name: \(name) id: \(identifier) rssi: \(rssi)")
        tableViewData.append([NSUserInterfaceItemIdentifier("Device"):name,
                              NSUserInterfaceItemIdentifier("Identifier"):identifier.uuidString,
                              NSUserInterfaceItemIdentifier("RSSI"):"\(rssi)"])
        devicePosition[identifier] = tableViewData.count-1
        self.deviceTable.reloadData()
        self.deviceTable.selectRowIndexes(IndexSet(integer: tableViewData.count-1), byExtendingSelection: false)
    }

    func updateRSSI(name: String, identifier: UUID, rssi: Int) {
        if let position = devicePosition[identifier] {
            NSLog("update rssi: name: \(name) id: \(identifier) rssi: \(rssi)")
            tableViewData[position] = [NSUserInterfaceItemIdentifier("Device"): name,
                                        NSUserInterfaceItemIdentifier("Identifier"): identifier.uuidString,
                                        NSUserInterfaceItemIdentifier("RSSI"): "\(rssi)"]
            self.deviceTable.reloadData()
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return tableViewData.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return tableViewData[row][tableColumn!.identifier]
    }

    func shareProgress(state: CrossplatformDropState, progress: Int) {
        NSLog("state: \(state)")
        if progress != -1 {
            NSLog("progress: \(progress)")
            if progressBar.isIndeterminate {
                progressBar.stopAnimation(self)
                progressBar.isIndeterminate = false
            }
            progressBar.doubleValue = Double(progress)
        }
        if state == CrossplatformDropState.CONNECTING_PERVIOUS_WIFI {
            bigLabel.stringValue = "Connecting back to previous wifi"
        }
        if state == CrossplatformDropState.CONNECTED_PERVIOUS_WIFI {
            bigLabel.stringValue = "Connected back to previous wifi"
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                self.view.window?.performClose(nil)
            }
        }
        if state == CrossplatformDropState.TRANSFER_DONE {
            bigLabel.stringValue = "Transfer succeeded"
        }
        if state == CrossplatformDropState.TRANSFER_FAILED {
            bigLabel.stringValue = "Transfer failed"
        }
        if state == CrossplatformDropState.BLE_ON {
            self.crossplatformDropModule.scanForDevices()
        }
        if state == CrossplatformDropState.CONNECTING {
            bigLabel.stringValue = "Connecting to device"
        }
        if state == CrossplatformDropState.CONNECTED {
            bigLabel.stringValue = "Connected to device"
        }
        if state == CrossplatformDropState.SHARING || state == CrossplatformDropState.SENDING {
            bigLabel.stringValue = "Sending file to device"
        }
    }

    func shareFile(_ path: NSString) {
        self.crossplatformDropModule.shareFile(path)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    public override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        print("init")
    }

    override func loadView() {
        super.loadView()
        crossplatformDropModule.delegates.append(self)
        self.deviceTable.dataSource = self
        crossplatformDropModule.initModule()
        crossplatformDropModule.scanForDevices()
        progressBar.startAnimation(self)
        bigLabel.stringValue = "Scanning for devices:"
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        print("disappear")
        crossplatformDropModule.deinitModule()
    }

    @IBAction func send(_ sender: AnyObject?) {
        let selected = deviceTable.selectedRow
        var deviceID: UUID? = nil
        for device in devicePosition {
            if device.value == selected {
                deviceID = device.key
                break
            }
        }
        if deviceID != nil {
            self.crossplatformDropModule.connectDevice(identifier: deviceID!)
        }

        self.sendBtn.isEnabled = false

        if !crossplatformDropModule.hasFile {

            if let url = NSOpenPanel().selectUrl {
                var item: Any = RHEAEntityResolver.resolveEntity(url)

                if item is NSURL {
                    NSLog("URL")
                }
                if item is NSString {
                    NSLog("String")
                    let path = item as! NSString
                    self.crossplatformDropModule.shareFile(path)
                }
                NSLog("\(item)")
            } else {
                print("file selection was canceled")
            }
        }

        // Complete implementation by setting the appropriate value on the output item

        /*let outputItem = NSExtensionItem()
        let outputItems = [outputItem]
        self.extensionContext!.completeRequest(returningItems: outputItems, completionHandler: nil)*/
}

    @IBAction func cancel(_ sender: AnyObject?) {
        self.view.window?.performClose(nil)
    }

}
