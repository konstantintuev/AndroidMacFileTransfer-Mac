//
//  Utils.swift
//  ToggleHotspotAndroid
//
//  Created by Kosio on 28.04.19.
//  Copyright © 2019 Kosio. All rights reserved.
//

import Foundation
import CoreBluetooth
import CoreWLAN
import SystemConfiguration
import Reachability

public enum CrossplatformDropState {
    case BLE_ON
    case BLE_OFF
    case SCANNING
    case CONNECTING
    case CONNECTED
    case SHARING
    case SENDING
    case TRANSFER_DONE
    case TRANSFER_FAILED
    case CONNECTING_PERVIOUS_WIFI
    case CONNECTED_PERVIOUS_WIFI
}

public protocol CrossplatformDropModuleDelegate {
    func shareProgress(state: CrossplatformDropState, progress: Int)
    func foundDevice(name: String, identifier: UUID, rssi: Int)
    func updateRSSI(name: String, identifier: UUID, rssi: Int)
}

public class CrossplatformDropModule: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, CBPeripheralManagerDelegate {

    static let shared = CrossplatformDropModule()


    var centralManager: CBCentralManager
    var peripheralManager : CBPeripheralManager
    let reachability = Reachability()!

    var onePlusPhonePeripheral: CBPeripheral? = nil

    var serviceUUID = CBUUID.init(string: "63DC1570-461D-47C9-B62F-9A715392AF94")
    var writeCharacteristicsUUID = CBUUID.init(string: "67574D86-41F2-402D-9FC4-906321DFF90B")
    var readCharacteristicsUUID = CBUUID.init(string: "57104CBE-BE83-4DC1-A7DD-D32AFE8296F8")

    var notifyCharacteristicsUUID = CBUUID.init(string: "56F7B705-AE1E-460E-A72F-9DF587DC3BB4")

    var writeCharacteristics: CBCharacteristic? = nil
    var readCharacteristics: CBCharacteristic? = nil

    var notifyCharacteristics: CBCharacteristic? = nil

    var writeAdvertiseCharacteristicsUUID = CBUUID.init(string: "B01149BF-E680-4853-A445-CA023FA5675F")
    var advertiseServiceUUID = CBUUID.init(string: "F3EA9D08-1852-4ED5-BD8A-69826C2A92F2")

    private var deviceIpAdress = ""

    private var fileLocation = ""

    private var fileName = ""

    public var delegates: [CrossplatformDropModuleDelegate] = []

    var canScan = false

    var peripherals = [UUID : CBPeripheral]()

    var chosenDeviceIdentifier: UUID? = nil


    var hasFile: Bool {
        get {
            return !fileLocation.isEmpty
        }
    }

    private var canceled = false

    public override init() {
        self.centralManager = CBCentralManager(delegate: nil, queue: nil)
        self.peripheralManager = CBPeripheralManager(delegate:nil, queue: nil)
        super.init()
        self.centralManager.delegate = self
        self.peripheralManager.delegate = self
    }

    var rlSrc: CFRunLoopSource? = nil


    public func initModule() {
        var callback: SCDynamicStoreCallBack = { (store, _, info) in
            /* Do anything you want */
            CrossplatformDropModule.printLocal("SCDynamicStoreCallBack")
            var plist = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString)

            if plist == nil {
                CrossplatformDropModule.printLocal("plist is nil")
                return
            }

            CrossplatformDropModule.printLocal(plist!)

            if let address = plist!["Router" as CFString] as? String {
                CrossplatformDropModule.printLocal(address)
                let mySelf = Unmanaged<CrossplatformDropModule>.fromOpaque(info!).takeUnretainedValue()
                mySelf.setDeviceIP(address)
            }
        }
        var context = SCDynamicStoreContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        context.info = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let store = SCDynamicStoreCreate(nil, "Example" as CFString, callback, &context)
        if SCDynamicStoreSetNotificationKeys(store!, ["State:/Network/Global/IPv4"] as CFArray, nil) {
            rlSrc = SCDynamicStoreCreateRunLoopSource(kCFAllocatorDefault, store!, 0);
            CFRunLoopAddSource(CFRunLoopGetCurrent(), rlSrc, CFRunLoopMode.defaultMode);
            CrossplatformDropModule.printLocal("looping")
        }

    }

    func deinitModule() {
        canceled = true
        chosenDeviceIdentifier = nil
        if onePlusPhonePeripheral != nil {
            readyToCommand = false
            self.centralManager.cancelPeripheralConnection(self.onePlusPhonePeripheral!)
            self.onePlusPhonePeripheral = nil
        }
        if centralManager.isScanning {
            centralManager.stopScan()
        }
        if rlSrc != nil {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), rlSrc, CFRunLoopMode.defaultMode)
        }
        delegates = []
        peripherals = [UUID : CBPeripheral]()
        deviceIpAdress = ""
        fileLocation = ""
        fileName = ""
    }

    var shouldShare = false

    func shareFile(_ path: NSString) {
        fileLocation = path as String
        fileName = path.lastPathComponent
        if !readyToCommand || onePlusPhonePeripheral == nil || writeCharacteristics == nil {
            shouldShare = true
            return
        }
        if let data = "send_file".data(using: String.Encoding.utf8, allowLossyConversion: false) {
            onePlusPhonePeripheral!.writeValue(data, for: writeCharacteristics!, type: CBCharacteristicWriteType.withoutResponse)
        }
        delegates.forEach{delegate in delegate.shareProgress(state: .SHARING, progress: -1)}
    }

    var isSharingAFile = false
    private func setDeviceIP(_ address: String) {
        CrossplatformDropModule.printLocal("setDeviceIP: ", address)
        deviceIpAdress = address
        if isSharingAFile {
            isSharingAFile = false
            if !readyToCommand || onePlusPhonePeripheral == nil || writeCharacteristics == nil {
                return
            }
            // check notifying ?
            if let data = "filename/-#\(fileName)".data(using: String.Encoding.utf8, allowLossyConversion: false) {
                onePlusPhonePeripheral!.writeValue(data, for: writeCharacteristics!, type: CBCharacteristicWriteType.withoutResponse)
            }
        }
    }

    public func scanForDevices() {
        if canScan {
            if !centralManager.isScanning {
                centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
                delegates.forEach { delegate in
                    delegate.shareProgress(state: .SCANNING, progress: -1)
                }
                CrossplatformDropModule.printLocal("Start sanning...")
            }
        }
    }

    public func connectDevice(identifier: UUID) {
        chosenDeviceIdentifier = identifier
        onePlusPhonePeripheral = peripherals[identifier]
        centralManager.stopScan()
        CrossplatformDropModule.printLocal("Stop Scan")
        onePlusPhonePeripheral!.delegate = self
        CrossplatformDropModule.printLocal("Set delegate")
        centralManager.connect(onePlusPhonePeripheral!)
        CrossplatformDropModule.printLocal("connect")
        delegates.forEach{delegate in delegate.shareProgress(state: .CONNECTING, progress: -1)}
    }

    // Required. Invoked when the central manager’s state is updated.
     public func centralManagerDidUpdateState(_ manager: CBCentralManager) {
        switch manager.state {
        case .poweredOff:
            CrossplatformDropModule.printLocal("BLE has powered off")
            canScan = false
            if onePlusPhonePeripheral != nil {
                readyToCommand = false
                self.centralManager.cancelPeripheralConnection(self.onePlusPhonePeripheral!)
                self.onePlusPhonePeripheral = nil
            }
            if centralManager.isScanning {
                centralManager.stopScan()
            }
            delegates.forEach{delegate in delegate.shareProgress(state: .BLE_OFF, progress: -1)}
        case .poweredOn:
            CrossplatformDropModule.printLocal("BLE is now powered on")
            canScan = true
            delegates.forEach{delegate in delegate.shareProgress(state: .BLE_ON, progress: -1)}
        case .resetting:
            CrossplatformDropModule.printLocal("BLE is resetting")
            canScan = false
        case .unauthorized:
            CrossplatformDropModule.printLocal("Unauthorized BLE state")
            canScan = false
        case .unknown:
            CrossplatformDropModule.printLocal("Unknown BLE state")
            canScan = false
        case .unsupported:
            CrossplatformDropModule.printLocal("This platform does not support BLE")
            canScan = false
        @unknown default:
            canScan = false
}
    }

    // Invoked when the central manager discovers a peripheral while scanning.
    public func centralManager(_ manager: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData advertisement: [String: Any], rssi: NSNumber) {

        let identifier = peripheral.value(forKey: "identifier") as! NSUUID as UUID
        var msg = "Device : \(identifier) - RSSI : \(rssi) "

        var deviceName = "UnknownDevice - \(rssi)"

        if let name = peripheral.name {
            msg += "DeviceName : \(name) "
            deviceName = name
        } else {
            if let serviceData = advertisement[CBAdvertisementDataServiceDataKey] as? [NSObject:AnyObject]{
                msg += "serviceData : \(serviceData) "
            }
        }

        //CrossplatformDropModule.printLocal (msg)

        let shouldInform = peripherals[identifier] == nil

        peripherals[peripheral.identifier] = peripheral
        if chosenDeviceIdentifier != nil {
            connectDevice(identifier: chosenDeviceIdentifier!)
        } else {
            if shouldInform {
                delegates.forEach{delegate in delegate.foundDevice(name: deviceName, identifier: identifier, rssi: rssi.intValue)}
            } else {
                delegates.forEach{delegate in delegate.updateRSSI(name: deviceName, identifier: identifier, rssi: rssi.intValue)}
            }
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        CrossplatformDropModule.printLocal("Connected!")
        if peripheral.isEqual(to: onePlusPhonePeripheral) {
            onePlusPhonePeripheral!.discoverServices([serviceUUID])
        }
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        CrossplatformDropModule.printLocal("Fail To Connect!")
        if peripheral.isEqual(to: onePlusPhonePeripheral) {
            onePlusPhonePeripheral = nil
            readyToCommand = false
            writeCharacteristics = nil
            peripherals.removeAll()
            if chosenDeviceIdentifier != nil {
                CrossplatformDropModule.printLocal("Start sanning...")
                centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
            }
        }
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        CrossplatformDropModule.printLocal("Disconnect Peripheral!")
        if peripheral.isEqual(to: onePlusPhonePeripheral) {
            onePlusPhonePeripheral = nil
            readyToCommand = false
            writeCharacteristics = nil
            peripherals.removeAll()
            if chosenDeviceIdentifier != nil {
                CrossplatformDropModule.printLocal("Start sanning...")
                centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }

        for service in services {
            CrossplatformDropModule.printLocal(service)
        }

        peripheral.discoverCharacteristics([writeCharacteristicsUUID, readCharacteristicsUUID], for: services[0])
    }

    var readyToCommand: Bool = false

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            if characteristic.uuid == writeCharacteristicsUUID {
                writeCharacteristics = characteristic
                CrossplatformDropModule.printLocal(writeCharacteristics!)
            } else if characteristic.uuid == readCharacteristicsUUID {
                readCharacteristics = characteristic
                CrossplatformDropModule.printLocal(readCharacteristics!)
            } else if characteristic.uuid == notifyCharacteristicsUUID {
                notifyCharacteristics = characteristic
                CrossplatformDropModule.printLocal(notifyCharacteristics!)
            }
        }
        if writeCharacteristics != nil && readCharacteristics != nil{
            onePlusPhonePeripheral?.setNotifyValue(true, for: readCharacteristics!)
            readyToCommand = true
            delegates.forEach{delegate in delegate.shareProgress(state: .CONNECTED, progress: -1)}
            if shouldShare {
                shouldShare = false
                if let data = "send_file".data(using: String.Encoding.utf8, allowLossyConversion: false) {
                    onePlusPhonePeripheral!.writeValue(data, for: writeCharacteristics!, type: CBCharacteristicWriteType.withoutResponse)
                }
                delegates.forEach{delegate in delegate.shareProgress(state: .SHARING, progress: -1)}
            }
        } else {
            CrossplatformDropModule.printLocal("Specific Characteristic Not found")
            if onePlusPhonePeripheral != nil {
                readyToCommand = false
                self.centralManager.cancelPeripheralConnection(self.onePlusPhonePeripheral!)
                self.onePlusPhonePeripheral = nil
            }
            CrossplatformDropModule.printLocal("Start sanning...")
            centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if (error != nil) {
            CrossplatformDropModule.printLocal("Error reading characteristics: ", error?.localizedDescription);
            return;
        }

        if (characteristic.value != nil) {
            CrossplatformDropModule.printLocal(characteristic.value)
        }
    }

    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheralManager.state {
        case .poweredOn:
            let service = CBMutableService(type: advertiseServiceUUID, primary: true)
            let properties = CBCharacteristicProperties.writeWithoutResponse
            let characteristic = CBMutableCharacteristic(type: writeAdvertiseCharacteristicsUUID, properties: properties, value: nil, permissions: .writeable)
            service.characteristics = [characteristic]
            peripheralManager.add(service)
            //peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey : [advertiseServiceUUID]])
            CrossplatformDropModule.printLocal("Start advertising...")
        default:
            if peripheralManager.isAdvertising {
                peripheralManager.stopAdvertising()
            }
        }
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        var writeRequest = requests[0]
        if writeRequest.characteristic.uuid == writeAdvertiseCharacteristicsUUID {
            if let writeData = writeRequest.value {
                if let datastring = String(data: writeData, encoding: String.Encoding.utf8) {
                    CrossplatformDropModule.printLocal("didReceiveWrite: ", datastring)
                    if datastring.starts(with: "wifi/-#") {
                        let wifiInfo = datastring.components(separatedBy: "/-#")
                        DispatchQueue.global(priority: .background).async {
                            self.connectToWifi(ssid: wifiInfo[1], password: wifiInfo[2])
                        }
                    } else if datastring.starts(with: "socket_read/-#") {
                        chosenDeviceIdentifier = nil
                        if onePlusPhonePeripheral != nil {
                            readyToCommand = false
                            self.centralManager.cancelPeripheralConnection(self.onePlusPhonePeripheral!)
                            self.onePlusPhonePeripheral = nil
                        }
                        DispatchQueue.global(priority: .background).async {
                            do {
                                var data = try NSData.init(contentsOfFile: self.fileLocation) as Data
                                let fileSize = data.count
                                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: fileSize)
                                data.copyBytes(to: buffer, count: fileSize)

                                // 1
                                var writeStream: Unmanaged<CFWriteStream>?

                                // 2
                                CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                        self.deviceIpAdress as CFString,
                                        9265,
                                        nil,
                                        &writeStream)

                                let outputStream = writeStream!.takeRetainedValue()

                                if CFWriteStreamOpen(outputStream) == false {
                                    CrossplatformDropModule.printLocal("Could not open stream")
                                    return
                                }

                                var offset: Int = 0
                                var dataToSendSize: Int = fileSize

                                DispatchQueue.main.sync {
                                    self.delegates.forEach{delegate in delegate.shareProgress(state: .SENDING, progress: 0)}
                                }
                                var shouldContinue = true
                                repeat {
                                    if (CFWriteStreamCanAcceptBytes(outputStream)) {
                                        let bytesWritten = CFWriteStreamWrite(outputStream, &buffer[offset], dataToSendSize)
                                        CrossplatformDropModule.printLocal("ftp bytes written: \(bytesWritten)")
                                        if bytesWritten > 0 {
                                            offset += bytesWritten.littleEndian
                                            dataToSendSize -= bytesWritten
                                            let valueInDouble: Double = 100 - ((Double(dataToSendSize)/Double(fileSize)) * 100)
                                            DispatchQueue.main.sync {
                                                self.delegates.forEach{delegate in delegate.shareProgress(state: .SENDING, progress: Int(valueInDouble))}
                                            }
                                            continue
                                        } else if bytesWritten < 0 {
                                            // ERROR
                                            CrossplatformDropModule.printLocal("FTPUpload - ERROR")
                                            shouldContinue = false
                                            DispatchQueue.main.sync {
                                                self.delegates.forEach{delegate in delegate.shareProgress(state: .TRANSFER_FAILED, progress: -1)}
                                            }
                                            break
                                        } else if bytesWritten == 0 {
                                            // SUCCESS
                                            CrossplatformDropModule.printLocal("FTPUpload - Completed!!")
                                            shouldContinue = false
                                            DispatchQueue.main.sync {
                                                self.delegates.forEach{delegate in delegate.shareProgress(state: .TRANSFER_DONE, progress: -1)}
                                            }
                                            break
                                        }
                                    } else {
                                        usleep(200000)
                                        print(".", separator: "", terminator: "")
                                    }
                                } while shouldContinue && !self.canceled

                                CFWriteStreamClose(outputStream)
                                buffer.deallocate()

                                DispatchQueue.main.sync {
                                    self.delegates.forEach{delegate in delegate.shareProgress(state: .CONNECTING_PERVIOUS_WIFI, progress: -1)}
                                }

                                self.connectToWifi(ssid: "", password: nil)

                                DispatchQueue.main.sync {
                                    if self.rlSrc != nil {
                                        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), self.rlSrc, CFRunLoopMode.defaultMode)
                                        self.rlSrc = nil
                                    }
                                    self.reachability.whenReachable = { reachability in
                                        if reachability.connection == .wifi {
                                            CrossplatformDropModule.printLocal("Reachable via WiFi")
                                        } else {
                                            CrossplatformDropModule.printLocal("Reachable via Cellular")
                                        }
                                        self.delegates.forEach{delegate in delegate.shareProgress(state: .CONNECTED_PERVIOUS_WIFI, progress: -1)}
                                        reachability.stopNotifier()
                                    }
                                    self.reachability.whenUnreachable = { _ in
                                        CrossplatformDropModule.printLocal("Not reachable")
                                    }
                                    do {
                                        try self.reachability.startNotifier()
                                    } catch {
                                        CrossplatformDropModule.printLocal("Unable to start notifier")
                                    }
                                }
                            } catch let ex {
                                CrossplatformDropModule.printLocal(ex)
                            }
                        }
                    }
                }
            }
        }
    }

    private func connectToWifi(ssid: String, password: String?) {
        guard let cwInterface = CWWiFiClient.shared().interface() else {return}
        if password == nil && ssid.isEmpty {
            try! cwInterface.setPower(false)
            sleep(5)
            try! cwInterface.setPower(true)
            return
        }

        let lastSSID = cwInterface.ssid()

        CrossplatformDropModule.printLocal("Got wifi interface: ", cwInterface.interfaceName, " ", lastSSID)

        // get all networks
        do {
            var retries = 20
            var networksSet = try? cwInterface.scanForNetworks(withName: ssid, includeHidden: false)
            while networksSet?.first?.ssid == nil && retries > 0 && !self.canceled {
                retries -= 1
                sleep(5)
                CrossplatformDropModule.printLocal("Needed wifi not found")
                networksSet = try? cwInterface.scanForNetworks(withName: ssid, includeHidden: false)
            }

            if networksSet == nil {
                CrossplatformDropModule.printLocal("networksSet is nil")
                return
            }
            CrossplatformDropModule.printLocal("Got wifi networks: ", networksSet!.first!.ssid!, " lenght: ", networksSet!.endIndex)

            var selectedNetwork: CWNetwork? = nil

            // check if one of the scanned networks SSIDs matches network with SSID "network_name"
            for network in networksSet! {
                if let ssid = network.ssid {
                    CrossplatformDropModule.printLocal("Iterating wifi networks: ", ssid)

                    // perhaps you will have another for here, looping over NSDictionary with network name as key and password as value
                    if (ssid == ssid) {
                        CrossplatformDropModule.printLocal("Found wifi network: ", ssid)
                        selectedNetwork = network
                        break
                    }
                }
            }

            if selectedNetwork != nil {
                CrossplatformDropModule.printLocal("Connect wifi network: ", selectedNetwork!.ssid!)
                // finally connect to the selected network
                try? cwInterface.associate(to: selectedNetwork!, password: password)

                CrossplatformDropModule.printLocal("Connected to wifi network: ", selectedNetwork!.ssid!)

                self.isSharingAFile = true

            } else {
                CrossplatformDropModule.printLocal("selectedNetwork is nil")
            }
        } catch (let ex) {
            CrossplatformDropModule.printLocal(ex)
        }
    }

    public static func printLocal(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        var out = ""
        for item in items {
            out += "\(item)" + separator
        }
        NSLog(out)
    }
}
