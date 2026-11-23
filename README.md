# Bể Neon

Game idle hồ cá nước ngọt viết bằng Flutter. Một bể có sức chứa vô hạn với 10 loài gồm bảy màu, neon, betta, cá chuột, thần tiên, mún đỏ, đuôi kiếm, sọc ngựa, sặc mật ong và phượng hoàng.

[Thiết kế game và các cơ chế đã bàn](docs/game-design.md).

- Chạm vào hồ để rải mồi. Cá ký tự neon bơi tới và lớn dần.
- Cá giống cho các lứa mới. Rêu Java giúp cá con tránh bị cá lớn ăn.
- Chợ đề cử một con giống dựa trên màu đuôi. Một nút giữ con đó và bán các cá đã lớn còn lại.
- **Sổ tay hồ cá** cho xem tập tính từng loài và mua cặp giống. Cá đẻ trứng có ổ trứng, thời gian ấp và tỷ lệ nở riêng.
- Mua máy cho ăn, kho mồi và nâng bộ lọc. Màn nâng cấp dự báo xu/phút và thời gian hoàn vốn.
- Thức ăn thừa và xác cá làm nước xấu đi. Chạm xác cá để vớt, hoặc nuôi ốc ramshorn để rỉa xác.
- Tiến trình lưu trên máy và mô phỏng tối đa 8 giờ khi mở lại game.

## Cập nhật danh mục cá

Sổ tay đọc [catalog/fish-v1.json](catalog/fish-v1.json) từ nhánh `main` khi mở hoặc quay lại app. Game mở hồ bằng bản danh mục đã lưu trên máy và tải bản mới trong nền. Lần đầu chơi offline có sẵn 10 loài. Lỗi mạng hay JSON lỗi thì game dùng bản đã lưu.

Sửa danh mục rồi tăng `revision` trước khi đưa lên `main`. Mảng `species` quyết định thứ tự trong Sổ tay. Một loài có sẵn chỉ cần `id` và các trường muốn sửa, ví dụ `{"id":"neon","pairCost":150}`. Đặt `"available": false` để ẩn khỏi Sổ tay. Cá đã mua và lứa đang ấp vẫn tiếp tục vòng đời, kể cả khi mục đó bị bỏ khỏi danh mục.

Loài mới cần `id` duy nhất, `style`, `label`, `latin` và `habit`. Ví dụ dưới đây là một biến thể mún đỏ minh họa cách khai báo.

```json
{
  "id": "bluePlaty",
  "style": "platy",
  "label": "Mún lam",
  "latin": "Xiphophorus maculatus",
  "habit": "Cá mún màu lam, đẻ con trực tiếp.",
  "color": "#70AAFF",
  "pairCost": 120,
  "clutch": [20, 40]
}
```

- `style` dùng một trong 10 ID có sẵn trong file. Nó chọn hình dáng, chuyển động và cách hiển thị ổ trứng. Mục mới kế thừa thông số mặc định của kiểu đó. Legendary của bảy màu và tính lãnh thổ của betta thuộc về loài gốc.
- `color` dùng `#RRGGBB`. `glyph` đổi ký tự trong Sổ tay và các thẻ. `brood` nhận `live` hoặc `eggs`. Cá đẻ con đặt `incubation` bằng 0, cá đẻ trứng đặt số ngày ấp lớn hơn 0.
- `adultDays`, `lifeDays`, `clutch` và `spawnEvery` dùng khoảng `[thấp, cao]` tính cả hai đầu. Có thể chỉnh thêm `hatchRate`, `fryLoss`, `basePrice`, `vividDivisor`, `adultIncome`, `youngIncome`, `load`, `predation`, `schoolSize` và `spawnWater`.
- Giữ nguyên `id` của loài đã phát hành. Lần tải sau chỉ nhận `revision` cao hơn bản đã lưu. Muốn quay về nội dung cũ, đưa nội dung đó lên lại với `revision` mới.

## Chạy trên Android

Cài Flutter stable và hoàn tất môi trường Android theo [hướng dẫn Flutter](https://docs.flutter.dev/platform-integration/android/setup). Bản này dùng Flutter 3.50 trở lên.

```sh
flutter pub get
flutter run
```

Hồ phủ màn hình ở cả chiều dọc và ngang. Bấm **Quản lý** để mở chợ cá, chăm hồ, nâng cấp, sổ tay hoặc nhật ký.

Trong **Quản lý → Nhật ký**, nút **Tua 30 ngày** cho phép thử vòng sinh sản và lên lứa ngay. Bình thường, 2 phút ngoài đời tương ứng một ngày trong hồ.

## Kiểm tra và đóng gói

```sh
flutter analyze
flutter test
flutter build apk --debug
```
