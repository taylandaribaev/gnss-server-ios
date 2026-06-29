import Foundation

enum NetworkAddressProvider {
    static func localIPv4Addresses() -> [String] {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let firstAddress = pointer else {
            return []
        }
        defer { freeifaddrs(pointer) }

        var addresses: [(priority: Int, address: String)] = []
        var current: UnsafeMutablePointer<ifaddrs>? = firstAddress

        while let interface = current?.pointee {
            defer { current = interface.ifa_next }

            guard let socketAddress = interface.ifa_addr,
                  socketAddress.pointee.sa_family == UInt8(AF_INET) else {
                continue
            }

            let flags = Int32(interface.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0 else {
                continue
            }

            let name = String(cString: interface.ifa_name)
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                socketAddress,
                socklen_t(socketAddress.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )

            guard result == 0 else { continue }
            let address = String(cString: hostname)

            // en0 is normally Wi-Fi on iPhone. Other interfaces are still shown
            // as fallbacks because hotspot/VPN interface names aren't guaranteed.
            let priority = name == "en0" ? 0 : 1
            addresses.append((priority, address))
        }

        var seen = Set<String>()
        return addresses
            .sorted {
                if $0.priority == $1.priority {
                    return $0.address < $1.address
                }
                return $0.priority < $1.priority
            }
            .map(\.address)
            .filter { seen.insert($0).inserted }
    }
}
