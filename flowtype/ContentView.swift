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

enum DisplayMode: String, CaseIterable, Identifiable {
  case grid
  case column

  var id: String { rawValue }

  var label: String {
    switch self {
    case .grid: return "グリッド"
    case .column: return "カラム"
    }
  }

  var iconName: String {
    switch self {
    case .grid: return "square.grid.3x2"
    case .column: return "rectangle.grid.1x2"
    }
  }
}

struct ContentView: View {
  @EnvironmentObject var store: FontStore

  @State private var query: String = ""
  @State private var showMonospacedOnly: Bool = false
  @State private var sampleText: String = "The quick brown fox jumps over the lazy dog"
  @State private var size: Double = 24
  @State private var pinned: Set<FontInfo> = []
  @State private var displayMode: DisplayMode = .grid

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

  @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn

  var body: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      sidebar
    } content: {
      mainContent
    } detail: {
      comparePanel
    }
    .navigationTitle("Font Browser")
    .toolbar {
      ToolbarItemGroup(placement: .navigation) {
        viewModePicker
      }
      ToolbarItem(placement: .automatic) {
        sizeSlider
      }
    }
  }

  // 左: フィルタや設定
  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 12) {
      TextField("検索（Family/Name/PS）", text: $query)
        .textFieldStyle(.roundedBorder)

      Toggle("等幅のみ", isOn: $showMonospacedOnly)

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
  @ViewBuilder
  private var mainContent: some View {
    switch displayMode {
    case .grid:
      gridView
    case .column:
      columnView
    }
  }

  private var gridView: some View {
    ScrollView {
      let columns = [GridItem(.adaptive(minimum: 220), spacing: 12)]
      LazyVGrid(columns: columns, spacing: 16) {
        ForEach(filteredFonts, id: \.self) { f in
          FontGridTile(
            font: f,
            sampleText: sampleText,
            size: size,
            pinned: $pinned
          )
        }
      }
      .padding(.horizontal, 18)
      .padding(.vertical, 16)
    }
  }

  private var columnView: some View {
    ScrollView {
      LazyVStack(spacing: 0, pinnedViews: []) {
        ForEach(Array(filteredFonts.enumerated()), id: \.element) { index, f in
          FontListRow(
            font: f,
            sampleText: sampleText,
            size: size,
            pinned: $pinned,
            isEvenRow: index.isMultiple(of: 2)
          )
        }
      }
      .padding(.vertical, 8)
    }
  }

  private var viewModePicker: some View {
    Picker("", selection: $displayMode) {
      ForEach(DisplayMode.allCases) { mode in
        Image(systemName: mode.iconName)
          .tag(mode)
          .help(mode.label)
          .accessibilityLabel(Text(mode.label))
      }
    }
    .pickerStyle(.segmented)
    .frame(width: 140)
  }

  private var sizeSlider: some View {
    HStack(spacing: 6) {
      Text("8")
        .foregroundStyle(.secondary)
      Slider(value: $size, in: 8...96, step: 1)
        .frame(width: 200)
      Text("96")
        .foregroundStyle(.secondary)
      Divider()
        .frame(height: 12)
      Text("\(Int(size)) pt")
        .monospacedDigit()
    }
    .padding(.vertical, 2)
  }

  // 右: 比較パネル（ピン留めフォントを縦に並べる）
  private var comparePanel: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("比較")
          .font(.caption).bold()
        Spacer()
        Button("コピー（テキストとフォント名）") {
          let text = pinned
            .map { "• \($0.displayName) [\($0.postScriptName)]\n  \(sampleText)" }
            .joined(separator: "\n\n")
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(text, forType: .string)
        }
        .font(.caption)
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
                    .font(.caption)
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

// MARK: - Item Views

struct FontGridTile: View {
  let font: FontInfo
  let sampleText: String
  let size: Double
  @Binding var pinned: Set<FontInfo>

  private var isPinned: Bool { pinned.contains(font) }
  private var titleText: String { "\(font.displayName) (\(font.postScriptName))" }

  var body: some View {
    ZStack(alignment: .topTrailing) {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(Color.primary.opacity(0.03))
        .overlay(
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )

      VStack(alignment: .leading, spacing: 12) {
        Text(titleText)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)

        Text(sampleText)
          .font(.custom(font.postScriptName, size: CGFloat(size)))
          .lineLimit(3)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)

        if font.isMonospaced {
          Label("等幅", systemImage: "text.alignleft")
            .font(.caption)
            .foregroundStyle(.secondary)
            .help("等幅フォント")
        }
      }
      .frame(maxWidth: .infinity, alignment: .topLeading)
      .padding(.horizontal, 16)
      .padding(.vertical, 14)

      Button {
        togglePin()
      } label: {
        Image(systemName: isPinned ? "pin.fill" : "pin")
          .padding(8)
          .background(.ultraThinMaterial, in: Circle())
      }
      .buttonStyle(.plain)
      .padding(10)
      .help(isPinned ? "ピン留めを外す" : "比較にピン留め")
    }
    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .contextMenu {
      Button {
        copyToPasteboard(font.postScriptName)
      } label: {
        Label("PostScript名をコピー", systemImage: "doc.on.doc")
      }

      Button {
        copyToPasteboard(font.displayName)
      } label: {
        Label("表示名をコピー", systemImage: "textformat")
      }

      Divider()

      Button {
        togglePin()
      } label: {
        Label(isPinned ? "ピン留めを外す" : "比較にピン留め", systemImage: isPinned ? "pin.slash" : "pin")
      }
    }
  }

  private func togglePin() {
    if isPinned {
      pinned.remove(font)
    } else {
      pinned.insert(font)
    }
  }

  private func copyToPasteboard(_ value: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
  }
}

struct FontListRow: View {
  let font: FontInfo
  let sampleText: String
  let size: Double
  @Binding var pinned: Set<FontInfo>
  let isEvenRow: Bool

  private var isPinned: Bool { pinned.contains(font) }
  
  // テキストサイズに応じて最大幅を計算（最小360、サイズが大きいほど広く）
  private var dynamicMaxWidth: CGFloat {
    let baseWidth: CGFloat = 360
    let sizeFactor = CGFloat(size) / 24.0 // 24ptを基準とする
    // サイズが大きいほど多くの文字を表示できるように幅を拡張
    // ただし上限を設けて右側のパネルに被らないようにする
    return min(baseWidth * sizeFactor, 800)
  }

  var body: some View {
    GeometryReader { geometry in
      HStack(spacing: 24) {
        HStack(alignment: .center, spacing: 12) {
          Circle()
            .fill(Color.accentColor.opacity(font.isMonospaced ? 1 : 0.5))
            .frame(width: 6, height: 6)
            .padding(.leading, 4)

          VStack(alignment: .leading, spacing: 2) {
            Text(font.displayName)
              .font(.caption)
              .lineLimit(1)
            Text(font.familyName)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
        .frame(width: 200, alignment: .leading)

        Spacer()

        Text(sampleText)
          .font(.custom(font.postScriptName, size: CGFloat(size)))
          .lineLimit(1)
          .minimumScaleFactor(0.5)
          .frame(maxWidth: min(dynamicMaxWidth, geometry.size.width - 400), alignment: .center)
          .padding(.horizontal, 12)

        Spacer(minLength: 12)

        HStack(spacing: 12) {
          Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(font.postScriptName, forType: .string)
          } label: {
            Image(systemName: "doc.on.doc")
          }
          .buttonStyle(.borderless)
          .help("PostScript名をコピー")

          Button {
            if isPinned { pinned.remove(font) } else { pinned.insert(font) }
          } label: {
            Image(systemName: isPinned ? "pin.fill" : "pin")
          }
          .buttonStyle(.borderless)
          .help(isPinned ? "ピン留めを外す" : "比較にピン留め")
        }
        .frame(width: 80, alignment: .trailing)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 14)
      .background(isEvenRow ? Color.primary.opacity(0.04) : Color.clear)
      .overlay(alignment: .bottom) {
        Divider()
          .padding(.leading, 20)
      }
    }
    .frame(height: 60)
  }
}

// MARK: - Preview

#Preview {
  ContentView()
    .environmentObject(FontStore())
}
