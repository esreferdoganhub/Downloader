import SwiftUI
import AppKit

struct ContentView: View {
    // Dosya kaydetme yolu her zaman belirli olsun (Downloads)
    init() {
        let defaultPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!.path
        if UserDefaults.standard.string(forKey: "downloadDirectoryPath") == nil {
            UserDefaults.standard.set(defaultPath, forKey: "downloadDirectoryPath")
        }
    }
    // Kullanıcı ayarları (AppStorage ile kalıcı)
    @AppStorage("themeMode") var themeMode: String = "system" // "system", "light", "dark"
    // Kullanıcı ayarları (AppStorage ile kalıcı)
    @AppStorage("autoBestQuality") var autoBestQuality = false
    @AppStorage("downloadPlaylist") var downloadPlaylist = false
    @AppStorage("selectedResolution") var storedResolution: Int = 0
    @AppStorage("downloadDirectoryPath") var downloadDirectoryPath: String = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!.path
    // Harici indirici (aria2c) her zaman kullanılsın
    let useExternalDownloader = true

    // Durum değişkenleri
    @State private var videoURL = ""
    @State private var availableResolutions: [Int] = []
    @State private var isFetchingInfo = false
    @State private var isDownloading = false
    @State private var progress: Double = 0
    @State private var message = ""
    @State private var showingErrorAlert = false  // Genel hata uyarısı
    @State private var urlDebounceWorkItem: DispatchWorkItem?

    private var selectedResolution: Binding<Int?> {
        Binding(get: { storedResolution == 0 ? nil : storedResolution }, set: { newVal in storedResolution = newVal ?? 0 })
    }

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Tema uyumlu arka plan
            GeometryReader { proxy in
                if colorScheme == .dark {
                    Color.black.ignoresSafeArea()
                } else {
                    LinearGradient(
                        gradient: Gradient(colors: [Color(red: 0.93, green: 0.95, blue: 1.0), Color(red: 0.85, green: 0.89, blue: 0.98)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                }
            }

            ScrollView(.vertical, showsIndicators: true) {
                VStack {
                    Spacer(minLength: 5)
                    // Gazze'ye destek mesajı
                    VStack(spacing: 10) {
                        Text("Bu uygulama Gazze'ye destek için tasarlanmıştır.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        HStack(spacing: 10) {
                            Text("Zulmün bitmesi ve adaletin tesisi için destek ol:")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Button(action: {
                                if let url = URL(string: "https://boykotdedektifi.org") {
                                    NSWorkspace.shared.open(url)
                                }
                            }) {
                                Text("boykotdedektifi.org")
                                    .font(.footnote)
                                    .underline()
                                    .foregroundColor(.blue)
                            }
                        }
                        // İletişim bölümü kaldırıldı (artık Help menüsünde olacak)
                    }
                    .padding(.bottom, 8)
                VStack(spacing: 24) {
                    // Tema toggle (sadece Açık/Koyu)
                    HStack(spacing: 12) {
                        Label("Nur", systemImage: "sun.max.fill")
                            .labelStyle(.iconOnly)
                            .foregroundColor(.yellow)
                        Toggle(isOn: Binding(
                            get: { themeMode == "dark" },
                            set: { themeMode = $0 ? "dark" : "light" }
                        )) {
                            Text(themeMode == "dark" ? "Koyu" : "Nur")
                                .foregroundColor(themeMode == "dark" ? .white : .primary)
                        }
                        .toggleStyle(.switch)
                        .frame(width: 80)
                        Label("Koyu", systemImage: "moon.fill")
                            .labelStyle(.iconOnly)
                            .foregroundColor(.purple)
                    }
                    .padding(.vertical, 8)
                    // Başlık
                    Text("YouTube Video İndirici")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .leading, endPoint: .trailing))
                        .padding(.top, 10)

                    // URL girişi ve otomatik format yükleme
                    HStack(spacing: 12) {
                        TextField("Video URL yapıştırın", text: $videoURL)
                            .textFieldStyle(.plain)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.85))
                                    .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.18), lineWidth: 1)
                            )
                            .foregroundColor(colorScheme == .dark ? .white : .primary)
                            .disabled(isDownloading)
                            .onChange(of: videoURL) { _ in
                                guard !videoURL.isEmpty && !isFetchingInfo && !isDownloading else { return }
                                urlDebounceWorkItem?.cancel()
                                let workItem = DispatchWorkItem { fetchVideoInfo() }
                                urlDebounceWorkItem = workItem
                                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500), execute: workItem)
                            }
                        Button {
                            fetchVideoInfo()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.blue)
                                .padding(10)
                                .background(colorScheme == .dark ? Color.white.opacity(0.15) : Color.white.opacity(0.8))
                                .clipShape(Circle())
                                .shadow(color: Color.blue.opacity(0.10), radius: 2, x: 0, y: 1)
                        }
                        .buttonStyle(.plain)
                        .disabled(videoURL.isEmpty || isFetchingInfo || isDownloading || autoBestQuality)
                    }

                    // Çözünürlük seçimi
                    if isFetchingInfo {
                        ProgressView()
                        Text("Formatlar alınıyor...").italic()
                    } else if !availableResolutions.isEmpty && !autoBestQuality {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Format seçin:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Picker("Format", selection: selectedResolution) {
                                ForEach(availableResolutions, id: \.self) { res in
                                    Text("\(res)p").tag(res)
                                }
                                Text("MP3").tag(-1)
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    // Ayarlar toggles
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $autoBestQuality) {
                            Label("Otomatik en iyi kalite", systemImage: "star.fill")
                        }
                        Toggle(isOn: $downloadPlaylist) {
                            Label("Playlist Olarak İndir", systemImage: "music.note.list")
                        }
                        // Harici indirici her zaman aktif, toggle kaldırıldı
                        
                        
                    }
                    .toggleStyle(.switch)
                    .padding(.vertical, 10)

                    // İndirme klasörü seçimi ve açma
                    HStack(spacing: 10) {
                        Image(systemName: "folder")
                            .foregroundColor(.accentColor)
                        Text(downloadDirectoryPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .font(.footnote)
                        Spacer()
                        Button(action: chooseDirectory) {
                            Image(systemName: "folder.badge.plus")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .help("İndirme klasörünü seç")
                        Button(action: { openDirectory(path: downloadDirectoryPath) }) {
                            Image(systemName: "arrow.up.bin")
                                .foregroundColor(.purple)
                        }
                        .buttonStyle(.plain)
                        .help("Klasörü aç")
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(colorScheme == .dark ? Color.black : Color.white.opacity(0.85))
                            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                    )

                    // Daha etkileyici indirme butonu
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "rocket.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 18, weight: .bold))
                            Text("Hızlı ve güvenli indirme")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        ZStack {
                            // Hareketli gradient arka plan (indirme sırasında animasyonlu)
                            GeometryReader { geo in
                                let width = geo.size.width
                                let gradient = LinearGradient(
                                    gradient: Gradient(colors: isDownloading ? [Color.purple, Color.blue, Color.pink, Color.red] : [Color.red, Color.pink]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                Rectangle()
                                    .fill(gradient)
                                    .frame(height: 52)
                                    .cornerRadius(14)
                                    .shadow(color: Color.red.opacity(0.28), radius: 10, x: 0, y: 6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
                                    )
                                    .opacity((videoURL.isEmpty || isDownloading || (!autoBestQuality && selectedResolution.wrappedValue == nil)) ? 0.6 : 1)
                                    .animation(isDownloading ? .linear(duration: 1.2).repeatForever(autoreverses: true) : .default, value: isDownloading)
                            }
                            Button(action: downloadVideo) {
                                HStack(spacing: 12) {
                                    if isDownloading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.9)
                                    } else {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .font(.system(size: 22, weight: .bold))
                                    }
                                    Text(isDownloading ? "İndiriliyor..." : (autoBestQuality ? "En iyi kalite indir" : "İndir"))
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .shadow(color: Color.black.opacity(0.13), radius: 1, x: 0, y: 1)
                                }
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .foregroundColor(.white)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(videoURL.isEmpty || isDownloading || (!autoBestQuality && selectedResolution.wrappedValue == nil))
                        }
                    }

                    // İlerleme ve mesaj
                    if isDownloading {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .accentColor(.red)
                            .padding(.horizontal)
                    }
                    if !message.isEmpty {
                        Text(message)
                            .foregroundColor(.secondary)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                    .padding(28)
                    .background(
                        Group {
                            if colorScheme == .dark {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.black)
                                    .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)
                            } else {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.white.opacity(0.7))
                                    .shadow(color: Color.black.opacity(0.07), radius: 16, x: 0, y: 8)
                            }
                        }
                    )
                    .padding(.horizontal, 40)
                    Spacer(minLength: 0)
                }
            }
        }
        // Genel hata uyarısı
        .alert("İndirme Hatası", isPresented: $showingErrorAlert) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(message)
        }
        .frame(width: 600, height: 600, alignment: .center)
        .preferredColorScheme(
            themeMode == "system" ? nil :
            (themeMode == "dark" ? .dark : .light)
        )
    }

    // MARK: - İşlevler
    private func chooseDirectory() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        panel.begin { response in if response == .OK, let url = panel.url { downloadDirectoryPath = url.path } }
    }
    private func openDirectory(path: String) { NSWorkspace.shared.open(URL(fileURLWithPath: path)) }
    private func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
    private func findTool(named name: String) -> String? {
        if let url = Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "Tools") { return url.path }
        let candidates = ["/usr/local/bin/\(name)", "/opt/homebrew/bin/\(name)"]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) { return path }
        guard let paths = ProcessInfo.processInfo.environment["PATH"]?.split(separator: ":").map(String.init) else { return nil }
        for dir in paths { let full = "\(dir)/\(name)"; if FileManager.default.isExecutableFile(atPath: full) { return full } }
        return nil
    }

    private func fetchVideoInfo() {
        guard !videoURL.isEmpty else { return }
        isFetchingInfo = true; message = "Formatlar alınıyor..."; availableResolutions = []; selectedResolution.wrappedValue = nil
        DispatchQueue.global(qos: .utility).async {
            guard let yt = findTool(named: "yt-dlp") else {
                DispatchQueue.main.async { message = "yt-dlp bulunamadı."; showingErrorAlert = true; isFetchingInfo = false }
                return
            }
            var outputLog = ""
            let tmp = NSTemporaryDirectory() + "yt-dlp"
            try? FileManager.default.removeItem(atPath: tmp)
            try? FileManager.default.copyItem(atPath: yt, toPath: tmp)
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tmp)

            let proc = Process(); let pipe = Pipe()
            proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
            proc.arguments = ["-c", "\(tmp) -F \"\(videoURL)\""]
            proc.standardOutput = pipe; proc.standardError = pipe
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
                outputLog += str
            }
            do {
                try proc.run(); proc.waitUntilExit()
            } catch {
                DispatchQueue.main.async { message = "Komut hata: \(error.localizedDescription)"; showingErrorAlert = true; isFetchingInfo = false }
                return
            }
            let pattern = "(\\d{2,4})p"
            let heights = (try? NSRegularExpression(pattern: pattern) .matches(in: outputLog, range: NSRange(outputLog.startIndex..., in: outputLog)) .compactMap { Range($0.range(at:1), in: outputLog).flatMap { Int(outputLog[$0]) } }) ?? []
            let unique = Array(Set(heights)).sorted()
            DispatchQueue.main.async {
                isFetchingInfo = false
                if unique.isEmpty {
                    message = "Format bilgisi alınamadı. Çıktı:\n\(outputLog)"
                    showingErrorAlert = true
                } else {
                    availableResolutions = unique; selectedResolution.wrappedValue = unique.first!; message = "Kalite seçenekleri yüklendi."
                }
            }
        }
    }

    private func downloadVideo() {
        isDownloading = true; progress = 0; message = "İndiriliyor..."
        DispatchQueue.global(qos: .utility).async {
            guard let yt = findTool(named: "yt-dlp"), let ff = findTool(named: "ffmpeg") else {
                DispatchQueue.main.async { message = "Gerekli araçlar bulunamadı."; showingErrorAlert = true; isDownloading = false }
                return
            }
            var outputLog = ""
            let ar = findTool(named: "aria2c")
            let tmp = NSTemporaryDirectory() + "yt-dlp"
            try? FileManager.default.removeItem(atPath: tmp)
            try? FileManager.default.copyItem(atPath: yt, toPath: tmp)
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tmp)

            let noPl = downloadPlaylist ? "" : "--no-playlist"
            // MP3 seçiliyse önce en düşük çözünürlükte indir, sonra mp3'e çevir
            let isMp3 = selectedResolution.wrappedValue == -1
            let fmt: String
            if isMp3 {
                // En düşük çözünürlükte video indir
                fmt = "worstvideo+bestaudio/best"
            } else if autoBestQuality {
                fmt = "bestvideo+bestaudio/best"
            } else {
                fmt = "bestvideo[height<=\(storedResolution)] + bestaudio/best"
            }
            var args = ["\(tmp)", noPl]
            if let aria = ar {
                args.append("--external-downloader \"\(aria)\"")
                args.append("--external-downloader-args '-x16 -s16 -k1M'")
            }
            // Çıktı dosya adı (geçici dosya mp3 için)
            let outName = isMp3 ? "%(title)s_temp.%(ext)s" : "%(title)s.%(ext)s"
            args += ["-f \"\(fmt)\"", "--ffmpeg-location \"\(ff)\"", "--merge-output-format mp4", "-o \"\(downloadDirectoryPath)/\(outName)\"", "\"\(videoURL)\""]
            let cmd = args.filter { !$0.isEmpty }.joined(separator: " ")

            let proc = Process(); proc.executableURL = URL(fileURLWithPath: "/bin/zsh"); proc.arguments = ["-c", cmd]
            let pipe = Pipe(); proc.standardOutput = pipe; proc.standardError = pipe

            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
                DispatchQueue.main.async {
                    outputLog += str
                    if let rng = str.range(of: "(\\d{1,3}\\.?\\d)%", options: .regularExpression) {
                        let pct = Double(str[rng].dropLast()) ?? 0
                        progress = pct/100; message = "İndiriliyor: \(Int(pct))%"
                    }
                }
            }
            do {
                try proc.run()
            } catch {
                DispatchQueue.main.async { message = "Komut hata: \(error.localizedDescription)"; showingErrorAlert = true; isDownloading = false }
                return
            }

            proc.terminationHandler = { p in
                DispatchQueue.main.async {
                    pipe.fileHandleForReading.readabilityHandler = nil
                    if p.terminationStatus != 0 {
                        message = "İndirme hatası (çıkış kodu \(p.terminationStatus)): \n\(outputLog)"
                        showingErrorAlert = true
                        isDownloading = false
                        return
                    }
                    // Eğer mp3 isteniyorsa, ffmpeg ile mp3'e çevir
                    if isMp3 {
                        message = "MP3'e dönüştürülüyor..."
                        // Dosya adını bul
                        let fileManager = FileManager.default
                        let dir = downloadDirectoryPath
                        // temp dosya: .mp4 veya .mkv olabilir, en son indirilen dosyayı bul
                        let files = (try? fileManager.contentsOfDirectory(atPath: dir)) ?? []
                        let tempFile = files.filter { $0.hasSuffix("_temp.mp4") || $0.hasSuffix("_temp.mkv") }.sorted().last
                        guard let temp = tempFile else {
                            message = "Geçici dosya bulunamadı."; showingErrorAlert = true; isDownloading = false; return
                        }
                        let tempPath = dir + "/" + temp
                        let mp3Path = tempPath.replacingOccurrences(of: "_temp.mp4", with: ".mp3").replacingOccurrences(of: "_temp.mkv", with: ".mp3")
                        // ffmpeg komutu
                        let ffmpegCmd = "\(ff) -i \"\(tempPath)\" -vn -ab 192k -ar 44100 -y \"\(mp3Path)\""
                        let ffProc = Process(); ffProc.executableURL = URL(fileURLWithPath: "/bin/zsh"); ffProc.arguments = ["-c", ffmpegCmd]
                        let ffPipe = Pipe(); ffProc.standardOutput = ffPipe; ffProc.standardError = ffPipe
                        do {
                            try ffProc.run(); ffProc.waitUntilExit()
                        } catch {
                            message = "MP3 dönüştürme hatası: \(error.localizedDescription)"; showingErrorAlert = true; isDownloading = false; return
                        }
                        // Geçici dosyayı sil
                        try? fileManager.removeItem(atPath: tempPath)
                        if ffProc.terminationStatus == 0 {
                            message = "MP3 indirme ve dönüştürme tamamlandı."
                        } else {
                            message = "MP3 dönüştürme hatası (çıkış kodu \(ffProc.terminationStatus))."
                            showingErrorAlert = true
                        }
                        isDownloading = false
                        return
                    }
                    message = "İndirme tamamlandı."
                    isDownloading = false
                }
            }
        }
    }
}




@main
struct YouTubeDownloaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .help) {
                Button("İletişim: esrefdroid@gmail.com") {
                    if let url = URL(string: "mailto:esrefdroid@gmail.com") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowDelegate: WindowDelegate?
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first {
            window.styleMask.remove(.resizable)
            window.collectionBehavior.remove(.fullScreenPrimary)
            windowDelegate = WindowDelegate()
            window.delegate = windowDelegate
        }
        // Uygulama aktif olduğunda da tekrar kontrol et
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            if let window = NSApplication.shared.windows.first {
                window.styleMask.remove(.resizable)
            }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didUpdateNotification, object: nil, queue: .main) { _ in
            if let window = NSApplication.shared.windows.first {
                window.styleMask.remove(.resizable)
            }
        }
        
        // Help menüsüne iletişim ekleme kodu kaldırıldı (SwiftUI .commands ile eklendi)
    }
}
    


