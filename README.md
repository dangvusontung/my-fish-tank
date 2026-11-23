# Bể Neon

Game idle hồ cá nước ngọt viết bằng Flutter. Bản đầu tập trung vào một bể cá bảy màu có sức chứa vô hạn.

[Thiết kế game và các cơ chế đã bàn](docs/game-design.md).

- Chạm vào hồ để rải mồi. Cá ký tự neon bơi tới và lớn dần.
- Cá giống cho các lứa mới. Rêu Java giúp cá con tránh bị cá lớn ăn.
- Chợ đề cử một con giống dựa trên màu đuôi. Một nút giữ con đó và bán các cá đã lớn còn lại.
- Mua máy cho ăn và nâng bộ lọc. Thức ăn thừa và xác cá làm chất lượng nước giảm.
- Tiến trình lưu trên máy và mô phỏng tối đa 8 giờ khi mở lại game.

## Chạy trên Android

Cài Flutter stable và hoàn tất môi trường Android theo [hướng dẫn Flutter](https://docs.flutter.dev/platform-integration/android/setup). Bản này dùng Flutter 3.50 trở lên.

```sh
flutter pub get
flutter run
```

Hồ phủ màn hình ở cả chiều dọc và ngang. Bấm **Quản lý** để mở chợ cá, chăm hồ, nâng cấp hoặc nhật ký.

Trong **Quản lý → Nhật ký**, nút **Tua 30 ngày** cho phép thử vòng sinh sản và lên lứa ngay. Bình thường, 2 phút ngoài đời tương ứng một ngày trong hồ.

## Kiểm tra và đóng gói

```sh
flutter analyze
flutter test
flutter build apk --debug
```
