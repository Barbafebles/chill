import Foundation
import IOKit

@_silgen_name("IOHIDEventSystemClientCreate")
func IOHIDEventSystemClientCreate(_ allocator: CFAllocator?) -> Unmanaged<AnyObject>?

@_silgen_name("IOHIDEventSystemClientSetMatching")
func IOHIDEventSystemClientSetMatching(_ client: AnyObject, _ matching: CFDictionary?) -> Int32

@_silgen_name("IOHIDEventSystemClientCopyServices")
func IOHIDEventSystemClientCopyServices(_ client: AnyObject) -> Unmanaged<CFArray>?

@_silgen_name("IOHIDServiceClientCopyEvent")
func IOHIDServiceClientCopyEvent(_ service: AnyObject, _ type: Int64, _ options: Int32, _ timeout: Int64) -> Unmanaged<AnyObject>?

@_silgen_name("IOHIDServiceClientCopyProperty")
func IOHIDServiceClientCopyProperty(_ service: AnyObject, _ property: CFString) -> Unmanaged<AnyObject>?

@_silgen_name("IOHIDEventGetFloatValue")
func IOHIDEventGetFloatValue(_ event: AnyObject, _ field: UInt32) -> Double

public struct ThermalSensor: Sendable {
    public let name: String
    public let temperature: Double
}

public struct FanStatus: Sendable {
    public let id: Int
    public let currentRPM: Int
}

public final class SMCBridge: @unchecked Sendable {
    public static let shared = SMCBridge()

    private let kIOHIDEventTypeTemperature: Int64 = 15
    private let kIOHIDEventTypeFan: Int64 = 42

    public func getThermalSensors() -> [ThermalSensor] {
        guard let clientRef = IOHIDEventSystemClientCreate(kCFAllocatorDefault) else { return [] }
        let client = clientRef.takeRetainedValue()

        let matchingDict: [String: Any] = [
            "PrimaryUsagePage": 0xff00,
            "PrimaryUsage": 5
        ]

        _ = IOHIDEventSystemClientSetMatching(client, matchingDict as CFDictionary)
        guard let servicesRef = IOHIDEventSystemClientCopyServices(client) else { return [] }
        let services = servicesRef.takeRetainedValue() as [AnyObject]

        var results: [ThermalSensor] = []

        for service in services {
            guard let eventRef = IOHIDServiceClientCopyEvent(service, kIOHIDEventTypeTemperature, 0, 0) else { continue }
            let event = eventRef.takeRetainedValue()
            let temp = IOHIDEventGetFloatValue(event, 0xF0000)

            var sensorName = "SoC Sensor"
            if let propRef = IOHIDServiceClientCopyProperty(service, "Product" as CFString) {
                sensorName = (propRef.takeRetainedValue() as? String) ?? sensorName
            }

            if temp > 0.0 && temp < 115.0 {
                results.append(ThermalSensor(name: sensorName, temperature: temp))
            }
        }
        return results
    }

    public func getFanSpeed() -> [FanStatus] {
        guard let clientRef = IOHIDEventSystemClientCreate(kCFAllocatorDefault) else { return [] }
        let client = clientRef.takeRetainedValue()

        let matchingDict: [String: Any] = [
            "PrimaryUsagePage": 0xff00,
            "PrimaryUsage": 5
        ]

        _ = IOHIDEventSystemClientSetMatching(client, matchingDict as CFDictionary)
        guard let servicesRef = IOHIDEventSystemClientCopyServices(client) else { return [] }
        let services = servicesRef.takeRetainedValue() as [AnyObject]

        var fans: [FanStatus] = []
        var fanId = 0

        for service in services {
            if let eventRef = IOHIDServiceClientCopyEvent(service, kIOHIDEventTypeFan, 0, 0) {
                let event = eventRef.takeRetainedValue()
                let rpm = Int(IOHIDEventGetFloatValue(event, 0x2A0000))
                if rpm > 0 {
                    fans.append(FanStatus(id: fanId, currentRPM: rpm))
                    fanId += 1
                }
            }
        }
        return fans
    }
}