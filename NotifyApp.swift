import SwiftUI
import PhotosUI
import UserNotifications

@main
struct NotifyApp: App {
    init() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { _, _ in }
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

// Cho phép thông báo hiện cả khi app đang mở
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

struct ContentView: View {
    @State private var title = "Tiêu đề thông báo"
    @State private var message = "Nội dung do bạn viết"
    @State private var delaySeconds = 5.0
    @State private var pickerItem: PhotosPickerItem?
    @State private var image: UIImage?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Nội dung")) {
                    TextField("Tiêu đề", text: $title)
                    TextField("Nội dung", text: $message)
                }

                Section(header: Text("Ảnh đính kèm")) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Text(image == nil ? "Chọn ảnh" : "Đổi ảnh khác")
                    }
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 160)
                        Button("Bỏ ảnh", role: .destructive) {
                            self.image = nil
                            pickerItem = nil
                        }
                    }
                }

                Section(header: Text("Hiện sau \(Int(delaySeconds)) giây")) {
                    Slider(value: $delaySeconds, in: 1...60, step: 1)
                }

                Section {
                    Button("Gửi thông báo") { schedule() }
                }
            }
            .navigationTitle("Thông báo của tôi")
            .onChange(of: pickerItem) { item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let ui = UIImage(data: data) {
                        image = ui
                    }
                }
            }
        }
    }

    func schedule() {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default

        // Đính ảnh: ảnh phải được lưu thành file tạm trước khi gắn vào thông báo
        if let image,
           let jpeg = image.jpegData(compressionQuality: 0.8) {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".jpg")
            do {
                try jpeg.write(to: url)
                let attachment = try UNNotificationAttachment(identifier: "image",
                                                              url: url,
                                                              options: nil)
                content.attachments = [attachment]
            } catch {
                print("Không đính được ảnh: \(error)")
            }
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delaySeconds, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
