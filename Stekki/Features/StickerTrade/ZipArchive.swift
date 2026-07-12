//
//  ZipArchive.swift
//  Stekki
//
//  .stickertrade（実体はZIP）の読み書きに使う、依存ライブラリなしの最小ZIP実装。
//
//  - 書き込み: 無圧縮（stored）のみ。中身はPNGと小さなJSONで、PNGは既に圧縮済みのため
//    ZIPレベルで再圧縮するメリットがほぼなく、実装を小さく保てる。
//  - 読み込み: stored(0) と deflate(8) に対応（Finder等で再圧縮されたZIPも読めるように）。
//    暗号化・データディスクリプタ・ZIP64・マルチディスクは非対応として明示的に拒否する。
//
//  受信ファイルは信頼できない入力として扱い、すべての読み取りで境界チェックを行う。
//

import Foundation
import Compression

enum ZipArchiveError: Error, LocalizedError {
    case notZip
    case unsupported(String)
    case corrupted(String)

    var errorDescription: String? {
        switch self {
        case .notZip:
            return "ZIP形式のファイルではありません。"
        case .unsupported(let detail):
            return "対応していないZIP形式です（\(detail)）。"
        case .corrupted(let detail):
            return "ファイルが壊れています（\(detail)）。"
        }
    }
}

// MARK: - CRC32

enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { i in
        var c = UInt32(i)
        for _ in 0..<8 {
            c = (c & 1 == 1) ? (0xEDB8_8320 ^ (c >> 1)) : (c >> 1)
        }
        return c
    }

    static func checksum(_ data: Data) -> UInt32 {
        var c: UInt32 = ~0
        data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            for byte in buffer {
                c = table[Int((c ^ UInt32(byte)) & 0xFF)] ^ (c >> 8)
            }
        }
        return ~c
    }
}

// MARK: - 書き込み（stored のみ）

enum ZipArchiveWriter {

    /// 与えられたエントリを順に格納したZIPデータを作る（無圧縮）
    static func makeArchive(entries: [(name: String, data: Data)]) -> Data {
        var out = Data()
        var centralDirectory = Data()
        let (dosTime, dosDate) = dosDateTime(from: .now)

        for (name, payload) in entries {
            let nameBytes = Data(name.utf8)
            let crc = CRC32.checksum(payload)
            let size = UInt32(payload.count)
            let localHeaderOffset = UInt32(out.count)

            // ローカルファイルヘッダ
            out.appendU32(0x0403_4B50)
            out.appendU16(20)            // version needed
            out.appendU16(0x0800)        // flags: UTF-8ファイル名
            out.appendU16(0)             // method: stored
            out.appendU16(dosTime)
            out.appendU16(dosDate)
            out.appendU32(crc)
            out.appendU32(size)          // compressed size
            out.appendU32(size)          // uncompressed size
            out.appendU16(UInt16(nameBytes.count))
            out.appendU16(0)             // extra length
            out.append(nameBytes)
            out.append(payload)

            // セントラルディレクトリレコード
            centralDirectory.appendU32(0x0201_4B50)
            centralDirectory.appendU16(20)   // version made by
            centralDirectory.appendU16(20)   // version needed
            centralDirectory.appendU16(0x0800)
            centralDirectory.appendU16(0)    // method: stored
            centralDirectory.appendU16(dosTime)
            centralDirectory.appendU16(dosDate)
            centralDirectory.appendU32(crc)
            centralDirectory.appendU32(size)
            centralDirectory.appendU32(size)
            centralDirectory.appendU16(UInt16(nameBytes.count))
            centralDirectory.appendU16(0)    // extra length
            centralDirectory.appendU16(0)    // comment length
            centralDirectory.appendU16(0)    // disk number start
            centralDirectory.appendU16(0)    // internal attrs
            centralDirectory.appendU32(0)    // external attrs
            centralDirectory.appendU32(localHeaderOffset)
            centralDirectory.append(nameBytes)
        }

        let centralDirectoryOffset = UInt32(out.count)
        out.append(centralDirectory)

        // End of Central Directory
        out.appendU32(0x0605_4B50)
        out.appendU16(0)                             // disk number
        out.appendU16(0)                             // central dir start disk
        out.appendU16(UInt16(entries.count))
        out.appendU16(UInt16(entries.count))
        out.appendU32(UInt32(centralDirectory.count))
        out.appendU32(centralDirectoryOffset)
        out.appendU16(0)                             // comment length
        return out
    }

    private static func dosDateTime(from date: Date) -> (time: UInt16, date: UInt16) {
        let c = Calendar(identifier: .gregorian).dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: date
        )
        let year = min(max(c.year ?? 1980, 1980), 2107)
        let dosDate = UInt16((year - 1980) << 9 | (c.month ?? 1) << 5 | (c.day ?? 1))
        let dosTime = UInt16((c.hour ?? 0) << 11 | (c.minute ?? 0) << 5 | (c.second ?? 0) / 2)
        return (dosTime, dosDate)
    }
}

// MARK: - 読み込み（stored / deflate）

struct ZipEntryInfo {
    let name: String
    let method: Int          // 0 = stored, 8 = deflate
    let crc32: UInt32
    let compressedSize: Int
    let uncompressedSize: Int
    let localHeaderOffset: Int
}

struct ZipArchiveReader {
    /// パースするエントリ数の上限（.stickertrade は4エントリ固定なので十分大きい値）
    static let maxEntryCount = 16
    /// 1エントリの展開後サイズの絶対上限（呼び出し側の個別上限とは別の安全弁）
    static let maxEntryUncompressedBytes = 32 * 1024 * 1024

    private let data: Data
    let entries: [ZipEntryInfo]

    init(data: Data) throws {
        self.data = data

        // --- End of Central Directory を末尾から探す ---
        let eocdMinSize = 22
        guard data.count >= eocdMinSize else { throw ZipArchiveError.notZip }
        let scanLimit = max(0, data.count - eocdMinSize - 65_536)
        var eocdOffset = -1
        var cursor = data.count - eocdMinSize
        while cursor >= scanLimit {
            if try Self.u32(data, cursor) == 0x0605_4B50 {
                eocdOffset = cursor
                break
            }
            cursor -= 1
        }
        guard eocdOffset >= 0 else { throw ZipArchiveError.notZip }

        guard try Self.u16(data, eocdOffset + 4) == 0,
              try Self.u16(data, eocdOffset + 6) == 0 else {
            throw ZipArchiveError.unsupported("マルチディスク")
        }
        let entryCount = try Self.u16(data, eocdOffset + 10)
        let centralDirectorySize = try Self.u32(data, eocdOffset + 12)
        let centralDirectoryOffset = try Self.u32(data, eocdOffset + 16)

        guard entryCount <= Self.maxEntryCount else {
            throw ZipArchiveError.unsupported("エントリ数が多すぎます")
        }
        guard centralDirectoryOffset + centralDirectorySize <= eocdOffset else {
            throw ZipArchiveError.corrupted("セントラルディレクトリの位置が不正")
        }

        // --- セントラルディレクトリをパースする ---
        var parsed: [ZipEntryInfo] = []
        var offset = centralDirectoryOffset
        let centralDirectoryEnd = centralDirectoryOffset + centralDirectorySize
        for _ in 0..<entryCount {
            guard try Self.u32(data, offset) == 0x0201_4B50 else {
                throw ZipArchiveError.corrupted("セントラルディレクトリのシグネチャ不一致")
            }
            let flags = try Self.u16(data, offset + 8)
            let method = try Self.u16(data, offset + 10)
            let crc = UInt32(try Self.u32(data, offset + 16))
            let compressedSize = try Self.u32(data, offset + 20)
            let uncompressedSize = try Self.u32(data, offset + 24)
            let nameLength = try Self.u16(data, offset + 28)
            let extraLength = try Self.u16(data, offset + 30)
            let commentLength = try Self.u16(data, offset + 32)
            let localHeaderOffset = try Self.u32(data, offset + 42)

            // 暗号化(bit0)・データディスクリプタ(bit3)は非対応
            guard flags & 0x0001 == 0, flags & 0x0008 == 0 else {
                throw ZipArchiveError.unsupported("暗号化またはデータディスクリプタ付き")
            }
            guard method == 0 || method == 8 else {
                throw ZipArchiveError.unsupported("圧縮方式 \(method)")
            }
            // 0xFFFFFFFF は ZIP64 の印
            guard compressedSize != 0xFFFF_FFFF, uncompressedSize != 0xFFFF_FFFF,
                  localHeaderOffset != 0xFFFF_FFFF else {
                throw ZipArchiveError.unsupported("ZIP64")
            }
            guard uncompressedSize <= Self.maxEntryUncompressedBytes else {
                throw ZipArchiveError.unsupported("エントリが大きすぎます")
            }
            guard nameLength > 0, nameLength <= 255 else {
                throw ZipArchiveError.corrupted("エントリ名の長さが不正")
            }
            let nameData = try Self.sub(data, offset + 46, nameLength)
            guard let name = String(data: nameData, encoding: .utf8),
                  !name.contains("/"), !name.contains("\\"), !name.contains("\0") else {
                throw ZipArchiveError.corrupted("エントリ名が不正")
            }

            parsed.append(ZipEntryInfo(
                name: name,
                method: method,
                crc32: crc,
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize,
                localHeaderOffset: localHeaderOffset
            ))
            offset += 46 + nameLength + extraLength + commentLength
            guard offset <= centralDirectoryEnd else {
                throw ZipArchiveError.corrupted("セントラルディレクトリの長さ不一致")
            }
        }
        self.entries = parsed
    }

    /// エントリを展開して返す。展開後サイズ・CRC32がセントラルディレクトリの宣言と一致することを検証する。
    func extractData(of entry: ZipEntryInfo) throws -> Data {
        let localOffset = entry.localHeaderOffset
        guard try Self.u32(data, localOffset) == 0x0403_4B50 else {
            throw ZipArchiveError.corrupted("ローカルヘッダのシグネチャ不一致")
        }
        // ローカルヘッダ側のname/extra長はセントラルディレクトリと異なることがあるため、ローカル側の値で読み飛ばす
        let nameLength = try Self.u16(data, localOffset + 26)
        let extraLength = try Self.u16(data, localOffset + 28)
        let dataStart = localOffset + 30 + nameLength + extraLength
        let raw = try Self.sub(data, dataStart, entry.compressedSize)

        let output: Data
        switch entry.method {
        case 0:
            guard entry.compressedSize == entry.uncompressedSize else {
                throw ZipArchiveError.corrupted("storedエントリのサイズ不一致")
            }
            output = raw
        case 8:
            output = try Self.inflateRawDeflate(raw, uncompressedSize: entry.uncompressedSize)
        default:
            throw ZipArchiveError.unsupported("圧縮方式 \(entry.method)")
        }

        guard output.count == entry.uncompressedSize else {
            throw ZipArchiveError.corrupted("展開後サイズが宣言と不一致")
        }
        guard CRC32.checksum(output) == entry.crc32 else {
            throw ZipArchiveError.corrupted("CRC32不一致")
        }
        return output
    }

    // MARK: - 下位ヘルパー

    /// ZIPのdeflate（生deflate、zlibヘッダなし）を展開する。
    /// AppleのCompressionフレームワークの COMPRESSION_ZLIB は生deflateを指す。
    private static func inflateRawDeflate(_ input: Data, uncompressedSize: Int) throws -> Data {
        guard uncompressedSize > 0 else { return Data() }
        guard !input.isEmpty else { throw ZipArchiveError.corrupted("deflateデータが空") }
        var output = Data(count: uncompressedSize)
        let written = output.withUnsafeMutableBytes { (dst: UnsafeMutableRawBufferPointer) -> Int in
            input.withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Int in
                compression_decode_buffer(
                    dst.bindMemory(to: UInt8.self).baseAddress!,
                    uncompressedSize,
                    src.bindMemory(to: UInt8.self).baseAddress!,
                    input.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        guard written == uncompressedSize else {
            throw ZipArchiveError.corrupted("deflate展開に失敗")
        }
        return output
    }

    // Dataがスライスでも安全なよう、常に startIndex 基準のオフセットで読む
    private static func u16(_ data: Data, _ offset: Int) throws -> Int {
        guard offset >= 0, offset + 2 <= data.count else {
            throw ZipArchiveError.corrupted("範囲外の読み取り")
        }
        let base = data.startIndex + offset
        return Int(data[base]) | Int(data[base + 1]) << 8
    }

    private static func u32(_ data: Data, _ offset: Int) throws -> Int {
        guard offset >= 0, offset + 4 <= data.count else {
            throw ZipArchiveError.corrupted("範囲外の読み取り")
        }
        let base = data.startIndex + offset
        return Int(data[base])
            | Int(data[base + 1]) << 8
            | Int(data[base + 2]) << 16
            | Int(data[base + 3]) << 24
    }

    private static func sub(_ data: Data, _ offset: Int, _ length: Int) throws -> Data {
        guard offset >= 0, length >= 0, offset + length <= data.count else {
            throw ZipArchiveError.corrupted("範囲外の読み取り")
        }
        let base = data.startIndex + offset
        return data.subdata(in: base..<(base + length))
    }
}

// MARK: - リトルエンディアン追記ヘルパー

private extension Data {
    mutating func appendU16(_ value: UInt16) {
        append(contentsOf: [UInt8(value & 0xFF), UInt8(value >> 8)])
    }

    mutating func appendU32(_ value: UInt32) {
        append(contentsOf: [
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 24) & 0xFF),
        ])
    }
}
