# YouTube Video İndirici (macOS)

Bu uygulama, modern SwiftUI ile geliştirilmiş, sabit boyutlu ve sade bir YouTube video/müzik indiricidir. macOS için optimize edilmiştir ve harici araçlarla (yt-dlp, aria2c, ffmpeg) yüksek hızlı indirme ve MP3 dönüştürme desteği sunar.

## Özellikler

- **Modern ve şık arayüz**: Koyu/Açık tema desteği, tema geçişi.
- **Sabit boyutlu pencere**: 600x600, mouse ile boyutlandırılamaz, tam ekran yapılamaz.
- **YouTube video ve müzik indirme**: Video çözünürlüğü seçimi veya doğrudan MP3 indirme.
- **MP3 Dönüştürme**: En düşük kalite video indirilip otomatik olarak MP3'e dönüştürülür.
- **Harici hızlı indirme**: aria2c ile çoklu bağlantı desteği (varsa otomatik kullanılır).
- **Playlist desteği**: Tek video veya tüm oynatma listesini indirme.
- **Kullanıcı dostu hata yönetimi**: Eksik araçlar veya indirme hatalarında bilgilendirme.
- **Gazze'ye destek mesajı ve boykot linki**.
- **İletişim**: Yardım menüsünde iletişim adresi.

## Gereksinimler

- macOS 12 veya üzeri
- [yt-dlp](https://github.com/yt-dlp/yt-dlp)
- [aria2c](https://aria2.github.io/) (isteğe bağlı, otomatik algılanır)
- [ffmpeg](https://ffmpeg.org/)

> Gerekli araçlar uygulamanın `Tools` klasöründe veya sistemde yüklü olmalıdır. Uygulama, sistemde bulamazsa hata mesajı gösterir.

## Kurulum

1. Gerekli araçları yükleyin:
   - Homebrew ile:  
     `brew install yt-dlp aria2 ffmpeg`
2. Uygulamayı Xcode ile açıp derleyin veya hazır binary'yi çalıştırın.
3. İndirme klasörünü seçin ve video/playlist URL'sini yapıştırın.

## Kullanım

- Video URL'sini girin, formatı seçin ve "İndir" butonuna tıklayın.
- MP3 seçerseniz, video otomatik olarak MP3'e dönüştürülür.
- Playlist indirmek için ilgili seçeneği aktif edin.
- Tema geçişi için üstteki anahtarı kullanın.
- Yardım menüsünden iletişim adresine ulaşabilirsiniz.

## Destek ve İletişim

Her türlü soru ve öneriniz için: **esrefdroid@gmail.com**

---

Bu uygulama Gazze'ye destek amacıyla geliştirilmiştir. Lütfen zulme karşı duyarlı olun ve boykot için [boykotdedektifi.org](https://boykotdedektifi.org) adresini ziyaret edin.
