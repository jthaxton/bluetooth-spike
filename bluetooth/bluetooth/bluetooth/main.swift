#!/usr/bin/env swift

import Foundation
import CoreBluetooth

class BluetoothAdvertiser: NSObject {
    private var peripheralManager: CBPeripheralManager!
    private var serviceUUID = CBUUID(string: "12345678-1234-1234-1234-123456789ABC")
    private var characteristicUUID = CBUUID(string: "87654321-4321-4321-4321-CBA987654321")
    private var characteristic: CBMutableCharacteristic!
    private var shouldStartAdvertising = false
    
    override init() {
        super.init()
        print("🔄 Initializing Bluetooth Peripheral Manager...")
        
        // Initialize without restore identifier to avoid the delegate issue
        let options: [String: Any] = [
            CBPeripheralManagerOptionShowPowerAlertKey: true
        ]
        peripheralManager = CBPeripheralManager(delegate: self, queue: DispatchQueue.main, options: options)
    }
    
    func startAdvertising() {
        print("📡 Request to start advertising...")
        shouldStartAdvertising = true
        
        // Check if we're ready, otherwise wait for state change
        checkAndStartAdvertising()
    }
    
    private func checkAndStartAdvertising() {
        print("🔍 Checking Bluetooth state: \(stateDescription(peripheralManager.state))")
        
        guard peripheralManager.state == .poweredOn else {
            if peripheralManager.state == .poweredOff {
                print("❌ Bluetooth is turned off. Please turn on Bluetooth and try again.")
                exit(1)
            }
            print("⏳ Waiting for Bluetooth to be ready...")
            return
        }
        
        guard shouldStartAdvertising else {
            return
        }
        
        setupServiceAndStartAdvertising()
        shouldStartAdvertising = false
    }
    
    private func setupServiceAndStartAdvertising() {
        print("⚙️ Setting up Bluetooth service...")
        
        // Create characteristic with proper properties
        characteristic = CBMutableCharacteristic(
            type: characteristicUUID,
            properties: [.read, .write, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )
        
        // Create service
        let service = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [characteristic]
        
        // Remove any existing services first
        peripheralManager.removeAllServices()
        
        // Add service to peripheral
        print("➕ Adding service to peripheral...")
        peripheralManager.add(service)
    }
    
    private func actuallyStartAdvertising() {
        let advertisementData: [String: Any] = [
            CBAdvertisementDataLocalNameKey: "Mac-Swift-Tool",
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID]
        ]
        
        print("📢 Starting advertisement with data: \(advertisementData)")
        peripheralManager.startAdvertising(advertisementData)
    }
    
    func stopAdvertising() {
        peripheralManager.stopAdvertising()
        peripheralManager.removeAllServices()
        print("🛑 Stopped advertising")
    }
    
    private func stateDescription(_ state: CBManagerState) -> String {
        switch state {
        case .unknown: return "Unknown"
        case .resetting: return "Resetting"
        case .unsupported: return "Unsupported"
        case .unauthorized: return "Unauthorized"
        case .poweredOff: return "Powered Off"
        case .poweredOn: return "Powered On"
        @unknown default: return "Unknown State"
        }
    }
}

// MARK: - CBPeripheralManagerDelegate
extension BluetoothAdvertiser: CBPeripheralManagerDelegate {
    
    // This method is required when using restore identifier
    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
        print("🔄 Restoring peripheral manager state: \(dict)")
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        let stateDesc = stateDescription(peripheral.state)
        print("🔄 Bluetooth state updated: \(stateDesc)")
        
        switch peripheral.state {
        case .poweredOn:
            print("✅ Bluetooth is powered on and ready!")
            checkAndStartAdvertising()
            
        case .poweredOff:
            print("❌ Bluetooth is powered off")
            print("💡 Please turn on Bluetooth in System Preferences")
            
        case .resetting:
            print("🔄 Bluetooth is resetting...")
            
        case .unauthorized:
            print("🚫 Bluetooth access is unauthorized")
            print("💡 Grant Bluetooth permission in System Preferences > Security & Privacy > Privacy > Bluetooth")
            
        case .unsupported:
            print("❌ Bluetooth LE is not supported on this device")
            
        case .unknown:
            print("❓ Bluetooth state is unknown - initializing...")
            
        @unknown default:
            print("❓ Unknown Bluetooth state: \(peripheral.state.rawValue)")
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            print("❌ Error adding service: \(error.localizedDescription)")
            return
        }
        
        print("✅ Successfully added service: \(service.uuid)")
        print("🚀 Now starting advertisement...")
        actuallyStartAdvertising()
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("❌ Error starting advertising: \(error.localizedDescription)")
            print("Error code: \(error)")
        } else {
            print("🎉 Successfully started advertising!")
            print("📡 Your Mac is now discoverable as 'Mac-Swift-Tool'")
            print("🆔 Service UUID: \(serviceUUID)")
            print("🔧 Characteristic UUID: \(characteristicUUID)")
            print("\n✨ Ready to accept connections! Use a Bluetooth scanner app to find this device.")
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        print("📖 Read request from: \(request.central.identifier)")
        
        if request.characteristic.uuid == characteristicUUID {
            let timestamp = DateFormatter().string(from: Date())
            let responseData = "Hello from Mac! Time: \(timestamp)".data(using: .utf8)
            request.value = responseData
            peripheralManager.respond(to: request, withResult: .success)
            print("✅ Responded to read request")
        } else {
            peripheralManager.respond(to: request, withResult: .attributeNotFound)
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        print("✏️ Received \(requests.count) write request(s)")
        
        for request in requests {
            if request.characteristic.uuid == characteristicUUID {
                if let value = request.value {
                    let receivedString = String(data: value, encoding: .utf8) ?? "Binary data (\(value.count) bytes)"
                    print("📝 Received: '\(receivedString)'")
                }
                peripheralManager.respond(to: request, withResult: .success)
            } else {
                peripheralManager.respond(to: request, withResult: .attributeNotFound)
            }
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("🔔 Device \(central.identifier) subscribed to notifications")
        
        // Send welcome notification
        let welcomeMsg = "🎉 Connected to Mac Swift Tool!".data(using: .utf8)!
        let success = peripheralManager.updateValue(welcomeMsg, for: self.characteristic, onSubscribedCentrals: [central])
        
        if success {
            print("✅ Sent welcome notification")
        } else {
            print("⚠️ Could not send notification (transmission queue full)")
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("🔕 Device \(central.identifier) unsubscribed")
    }
}

// MARK: - Main Program
print("🚀 Bluetooth Peripheral Advertiser")
print("===================================")

let advertiser = BluetoothAdvertiser()

// Set up signal handling for clean exit
signal(SIGINT) { _ in
    print("\n🛑 Received interrupt signal, stopping...")
    advertiser.stopAdvertising()
    print("👋 Goodbye!")
    exit(0)
}

print("⏳ Initializing... (this may take a moment)")

// Give the peripheral manager time to initialize before requesting advertising
DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
    print("🎯 Requesting to start advertising...")
    advertiser.startAdvertising()
}



class Scanner: NSObject, CBCentralManagerDelegate {
    private var centralManager: CBCentralManager!
    private let targetService = CBUUID(string: "12345678-1234-1234-1234-123456789ABC")
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("🔍 Scanning for Bluetooth devices...")
            centralManager.scanForPeripherals(withServices: nil, options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: false
            ])
            
            // Stop after 15 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                self.centralManager.stopScan()
                print("🏁 Scan finished")
                exit(0)
            }
        } else {
            print("❌ Bluetooth not available: \(central.state)")
            exit(1)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                       advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown"
        let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        
        print("📱 Found: \(name) (RSSI: \(RSSI))")
        
        if !services.isEmpty {
            print("   Services: \(services.map { $0.uuidString })")
        }
        
        // Check if it's our device
        if services.contains(targetService) || name.contains("Mac-Swift-Tool") || name.contains("Mac-CLI-Tool") {
            print("   🎯 ** THIS IS YOUR MAC DEVICE! **")
        }
        
        print()
    }
}

//let scanner = Scanner()
//RunLoop.main.run()

print("Press Ctrl+C to stop advertising\n")

// Keep the program running
RunLoop.main.run()
