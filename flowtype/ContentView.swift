import SwiftUI
import CoreText
import AppKit

// MARK: - Model

struct FontInfo: Identifiable, Hashable {
  let id = UUID()
  let postScriptName: String
  let displayName: String
  let familyName: String
  let isMonospaced: Bool
}

// MARK: - Store

final class FontStore: ObservableObject {
  @Published var fonts: [FontInfo] = []

  init() { load() }

  func load() {
    var results: [FontInfo] = []

    // インストール済みフォントの PostScript 名一覧を取得
    if let psNames = CTFontManagerCopyAvailablePostScriptNames() as? [String] {
      results.reserveCapacity(psNames.count)

      for ps in psNames {
        let ct = CTFontCreateWithName(ps as CFString, 12, nil)
        let display = (CTFontCopyDisplayName(ct) as String?) ?? ps
        let family  = (CTFontCopyFamilyName(ct) as String?) ?? "Unknown"

        // 等幅判定: symbolic traits の MonoSpace ビット
        let traits = CTFontCopyTraits(ct) as NSDictionary
        let sym = traits[kCTFontSymbolicTrait] as? UInt32 ?? 0
        let kCTFontMonoSpaceTrait: UInt32 = 1 << 6
        let mono = (sym & kCTFontMonoSpaceTrait) != 0

        results.append(FontInfo(
          postScriptName: ps,
          displayName: display,
          familyName: family,
          isMonospaced: mono
        ))
      }
    }

    // 家族名 → 表示名 → PS名 で安定ソート
    self.fonts = results.sorted {
      if $0.familyName != $1.familyName { return $0.familyName < $1.familyName }
      if $0.displayName != $1.displayName { return $0.displayName < $1.displayName }
      return $0.postScriptName < $1.postScriptName
    }
  }
}

// MARK: - Root View

struct ContentView: View {
  @EnvironmentObject var store: FontStore

  @State private var query: String = ""
  @State private var showMonospacedOnly: Bool = false
  @State private var sampleText: String = "The quick brown fox jumps over the lazy dog 0123456789 あいうえお アイウエオ"
  @State private var size: Double = 24
  @State private var pinned: Set<FontInfo> = []

  var filteredFonts: [FontInfo] {
    store.fonts.filter { f in
      let hit =
        query.isEmpty
        || f.familyName.localizedCaseInsensitiveContains(query)
        || f.displayName.localizedCaseInsensitiveContains(query)
        || f.postScriptName.localizedCaseInsensitiveContains(query)
      let monoOK = !showMonospacedOnly || f.isMonospaced
      return hit && monoOK
    }
  }

  var body: some View {
    NavigationSplitView {
      sidebar
    } content: {
      grid
    } detail: {
      comparePanel
    }
    .navigationTitle("Font Browser")
  }

  // 左: フィルタや設定
  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 12) {
      TextField("検索（Family/Name/PS）", text: $query)
        .textFieldStyle(.roundedBorder)

      Toggle("等幅のみ", isOn: $showMonospacedOnly)

      VStack(alignment: .leading) {
        Text("サイズ: \(Int(size))")
        Slider(value: $size, in: 8...96, step: 1)
      }

      Text("サンプルテキスト")
      TextEditor(text: $sampleText)
        .frame(minHeight: 100)
        .border(Color.secondary.opacity(0.2))

      Divider()
      VStack(alignment: .leading, spacing: 6) {
        Text("ピン留め \(pinned.count) 件")
          .font(.caption)
          .foregroundStyle(.secondary)
        Button("すべて外す") { pinned.removeAll() }
          .buttonStyle(.bordered)
      }

      Spacer()
    }
    .padding()
  }

  // 中央: 一覧（カードグリッド）
  private var grid: some View {
    ScrollView {
      let columns = [GridItem(.adaptive(minimum: 240), spacing: 16)]
      LazyVGrid(columns: columns, spacing: 16) {
        ForEach(filteredFonts, id: \.self) { f in
          FontCard(
            font: f,
            sampleText: sampleText,
            size: size,
            pinned: $pinned
          )
        }
      }
      .padding(16)
    }
  }

  // 右: 比較パネル（ピン留めフォントを縦に並べる）
  private var comparePanel: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("比較")
          .font(.title3).bold()
        Spacer()
        Button("コピー（テキストとフォント名）") {
          let text = pinned
            .map { "• \($0.displayName) [\($0.postScriptName)]\n  \(sampleText)" }
            .joined(separator: "\n\n")
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(text, forType: .string)
        }
      }

      if pinned.isEmpty {
        if #available(macOS 14.0, *) {
          ContentUnavailableView("ピン留めなし", systemImage: "pin.slash", description: Text("一覧で📌を押すとここに並びます"))
        } else {
          VStack(spacing: 8) {
            Image(systemName: "pin.slash")
            Text("一覧で📌を押すとここに並びます")
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(pinned), id: \.self) { f in
              VStack(alignment: .leading, spacing: 6) {
                HStack {
                  Text(f.displayName)
                    .font(.headline)
                  Text("[\(f.postScriptName)]")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                  if f.isMonospaced {
                    Label("Monospaced", systemImage: "text.alignleft")
                      .labelStyle(.iconOnly)
                      .help("等幅")
                  }
                  Spacer()
                  Button {
                    pinned.remove(f)
                  } label: {
                    Image(systemName: "pin.slash")
                  }
                  .buttonStyle(.borderless)
                }
                Text(sampleText)
                  .font(.custom(f.postScriptName, size: CGFloat(size)))
                  .lineLimit(5)
                  .fixedSize(horizontal: false, vertical: true)
                  .padding(10)
                  .background(Color.secondary.opacity(0.12))
                  .clipShape(RoundedRectangle(cornerRadius: 8))
              }
              Divider()
            }
          }
          .padding()
        }
      }
    }
    .padding()
  }
}

// MARK: - Card

struct FontCard: View {
  let font: FontInfo
  let sampleText: String
  let size: Double
  @Binding var pinned: Set<FontInfo>

  private var isPinned: Bool { pinned.contains(font) }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(font.displayName)
            .font(.subheadline).bold()
            .lineLimit(1)
          Text("\(font.familyName) • \(font.postScriptName)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        Spacer()
        Button {
          if isPinned { pinned.remove(font) } else { pinned.insert(font) }
        } label: {
          Image(systemName: isPinned ? "pin.fill" : "pin")
        }
        .buttonStyle(.borderless)
        .help(isPinned ? "ピン留めを外す" : "比較にピン留め")
      }

      Text(sampleText)
        .font(.custom(font.postScriptName, size: CGFloat(size)))
        .lineLimit(4)
        .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: 6) {
        if font.isMonospaced {
          Label("等幅", systemImage: "text.alignleft").font(.caption2)
        }
        Spacer()
        Button {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(font.postScriptName, forType: .string)
        } label: {
          Label("PS名コピー", systemImage: "doc.on.doc")
            .labelStyle(.iconOnly)
        }
        .buttonStyle(.borderless)
        .help("PostScript名をコピー")
      }
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.primary.opacity(0.03))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
    )
  }
}

// MARK: - Preview

#Preview {
  ContentView()
    .environmentObject(FontStore())
}
