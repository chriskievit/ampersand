import Darwin
import Foundation

public enum ProcessTree {
    public struct Usage: Sendable, Equatable {
        public var cpuNanoseconds: UInt64
        public var residentBytes: UInt64
        public init(cpuNanoseconds: UInt64, residentBytes: UInt64) {
            self.cpuNanoseconds = cpuNanoseconds; self.residentBytes = residentBytes
        }
    }

    public static func pids(inGroup pgid: pid_t) -> [pid_t] {
        var capacity = 256
        while true {
            var buffer = [pid_t](repeating: 0, count: capacity)
            let bytes = proc_listpids(UInt32(PROC_PGRP_ONLY), UInt32(pgid), &buffer,
                                      Int32(capacity * MemoryLayout<pid_t>.size))
            guard bytes > 0 else { return [] }
            let count = Int(bytes) / MemoryLayout<pid_t>.size
            if count < capacity { return buffer.prefix(count).filter { $0 > 0 } }
            capacity *= 2
        }
    }

    public static func usage(of pids: [pid_t]) -> Usage {
        var total = Usage(cpuNanoseconds: 0, residentBytes: 0)
        for pid in pids {
            var info = rusage_info_v2()
            let rc = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_V2, $0)
                }
            }
            guard rc == 0 else { continue }
            let ticks = info.ri_user_time + info.ri_system_time
            total.cpuNanoseconds += UInt64(Double(ticks) * nanosecondsPerTick)
            total.residentBytes += info.ri_resident_size
        }
        return total
    }

    static let nanosecondsPerTick: Double = {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        return Double(timebase.numer) / Double(timebase.denom)
    }()
}
