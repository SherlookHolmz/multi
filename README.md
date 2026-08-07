# 🌍 Sherlook Multi-Location Node Manager

<p align="center">
  <b>🚀 ساخت و مدیریت Nodeهای چندلوکیشنه با انتخاب کشور</b>
</p>

<p align="center">
  <i>Multi-Location Node Management • Tor Exit Nodes • Xray • Pasarguard</i>
</p>

---

## ✨ معرفی

**Sherlook Multi** یک اسکریپت مدیریتی برای ساخت و مدیریت Nodeهای چندلوکیشنه است.

با انتخاب کشور موردنظر، سیستم می‌تواند Node مربوط به آن Location را ایجاد کرده و آن را در کانفیگ Xray قرار دهد.

🎯 هدف پروژه این است که مدیریت تعداد زیادی Location از طریق یک سرور اصلی ساده‌تر شود.

---

## 🌎 Locationهای قابل استفاده

سیستم از تعداد زیادی کشور و Location پشتیبانی می‌کند و هر کشور با Country Code مخصوص خودش مدیریت می‌شود.

نمونه:

| 🌍 Country          | 🇺🇳 Code |
| ------------------- | --------- |
| 🇺🇸 United States  | `US`      |
| 🇩🇪 Germany        | `DE`      |
| 🇳🇱 Netherlands    | `NL`      |
| 🇫🇷 France         | `FR`      |
| 🇬🇧 United Kingdom | `GB`      |
| 🇪🇸 Spain          | `ES`      |
| 🇮🇹 Italy          | `IT`      |
| 🇹🇷 Turkey         | `TR`      |
| 🇺🇦 Ukraine        | `UA`      |
| 🇨🇦 Canada         | `CA`      |
| 🇯🇵 Japan          | `JP`      |
| 🇸🇬 Singapore      | `SG`      |
| 🇦🇺 Australia      | `AU`      |
| 🇧🇷 Brazil         | `BR`      |
| 🇮🇳 India          | `IN`      |

> تعداد Locationها و لیست کشورها می‌تواند در نسخه‌های مختلف پروژه تغییر کند.

---

# 🚀 Easy Install

برای نصب سریع، کافی است دستور زیر را روی سرور اجرا کنید:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/SherlookHolmz/multi/main/sherlook.sh)
```

یا با `curl`:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/SherlookHolmz/multi/main/sherlook.sh)
```

> ⚡ پیشنهاد می‌شود دستور `bash <(...)` را استفاده کنید تا اسکریپت در محیط‌های تعاملی بدون مشکل ورودی اجرا شود.

---

# 🛠️ نصب دستی

اگر می‌خواهید ابتدا فایل را دانلود و سپس اجرا کنید:

```bash
wget -O sherlook.sh https://raw.githubusercontent.com/SherlookHolmz/multi/main/sherlook.sh
```

سپس:

```bash
chmod +x sherlook.sh
./sherlook.sh
```

---

# 📋 Main Menu

بعد از اجرای اسکریپت، منوی اصلی در اختیار شما قرار می‌گیرد:

```text
[1] Install Engine & Core Tools
[2] Update System
[3] Uninstall System

[4] Add Location Node (Single)
[5] Bulk Add Nodes (Multiple/All)
[6] View Active Nodes
[7] Edit or Delete Nodes
[8] Advanced Port Settings

[9] Panel Pasarguard Integration

[0] Exit Program
```

---

# ⚙️ Engine

اسکریپت ابزارهای موردنیاز را بررسی و در صورت نیاز نصب می‌کند.

ابزارهای اصلی پروژه شامل:

* 🧅 Tor
* 📦 jq
* 🌐 curl
* 🔧 ابزارهای موردنیاز سیستم

هستند.

---

# 🌍 Add Location Node

با گزینه:

```text
[4] Add Location Node (Single)
```

می‌توانید یک Location را انتخاب کنید.

فرآیند کلی:

```text
Select Country
      ↓
Country Code
      ↓
Tor Exit Node
      ↓
Public IP
      ↓
Location Verification
      ↓
Xray Node
```

در نسخه‌های جدید، Location خروجی نیز بررسی می‌شود تا IP اشتباه به‌عنوان کشور انتخاب‌شده ثبت نشود.

---

# 🔥 Bulk Add Nodes

با گزینه:

```text
[5] Bulk Add Nodes
```

می‌توانید چند Location یا Locationهای مختلف را به‌صورت گروهی ایجاد کنید.

این قابلیت برای ساخت تعداد زیادی Node از یک سرور مرکزی طراحی شده است.

---

# 🔍 Location Verification

یکی از بخش‌های مهم پروژه، بررسی Location واقعی IP خروجی است.

برای مثال اگر کاربر انتخاب کند:

```text
🇪🇸 Spain
```

سیستم نباید صرفاً به Country Code داخلی اکتفا کند.

بلکه خروجی باید بررسی شود:

```text
Requested Country: ES
        ↓
Tor Exit
        ↓
Public IP
        ↓
GeoIP Verification
        ↓
Country = ES
        ↓
✅ Valid
```

اگر خروجی مثلاً:

```text
UA
```

باشد:

```text
❌ Invalid Exit
```

و IP نباید به‌عنوان Spain ثبت شود.

---

# ♻️ Exit Management

سیستم برای جلوگیری از استفاده مجدد از Exitهای نامعتبر، Exitهای مشکل‌دار را مدیریت می‌کند.

در صورت مشاهده IP نامعتبر:

```text
Invalid IP
    ↓
Reject
    ↓
Blacklist / Exclude
    ↓
New Circuit
    ↓
New IP
    ↓
Verification
```

این مکانیزم مخصوصاً برای Locationهایی که Exitهای محدودی دارند اهمیت بیشتری دارد.

---

# ⚡ Performance

برای حفظ سرعت، بررسی Location نباید در هر استفاده از Node دوباره انجام شود.

منطق بهینه به این شکل است:

```text
Node Creation
      ↓
IP Verification
      ↓
✅ Verified
      ↓
Cache Result
      ↓
Normal Usage
```

اگر IP تغییر کند یا Node دوباره ساخته/Repair شود، Verification دوباره انجام می‌شود.

---

# 🔌 Xray

Nodeهای ایجادشده می‌توانند به ساختار Xray اضافه شوند.

فرآیند کلی:

```text
Country
   ↓
Tor SOCKS
   ↓
Xray Outbound
   ↓
Xray Inbound
   ↓
Routing Rule
```

برای هر Node پورت و Tag اختصاصی ایجاد می‌شود تا از تداخل Nodeها جلوگیری شود.

---

# 🛡️ Pasarguard Integration

پروژه امکان اتصال به پنل **Pasarguard** را نیز دارد.

با گزینه:

```text
[9] Panel Pasarguard Integration
```

می‌توان تنظیمات مربوط به پنل را انجام داد و Hostهای ایجادشده را از طریق API به پنل ارسال کرد.

---

# 🔧 Port Management

برای جلوگیری از تداخل، پورت‌های جدید به‌صورت خودکار انتخاب و بررسی می‌شوند.

سیستم موارد زیر را بررسی می‌کند:

* 🔹 تکراری نبودن Port
* 🔹 تکراری نبودن Inbound Tag
* 🔹 تکراری نبودن Outbound Tag

نمونه ساختار:

```text
ES-IN-XXXX
ES-OUT-XXXX
```

---

# 📊 Active Nodes

از طریق:

```text
[6] View Active Nodes
```

می‌توانید Nodeهای فعال ایجادشده توسط سیستم را مشاهده کنید.

---

# 🗑️ Node Management

گزینه:

```text
[7] Edit or Delete Nodes
```

برای مدیریت Nodeهای موجود استفاده می‌شود.

---

# 🧰 Requirements

سیستم باید یک سرور Linux داشته باشد.

ابزارهای اصلی مورد استفاده:

```text
bash
curl
wget
jq
tor
```

دسترسی:

```text
root
```

توصیه می‌شود.

---

# ⚠️ نکات مهم

* 🌐 Location یک IP همیشه تضمین‌کننده موقعیت فیزیکی دقیق سرور نیست.
* 🧅 اطلاعات Location مربوط به Exit Nodeها ممکن است بین دیتابیس‌های GeoIP متفاوت باشد.
* ⚡ تعداد Exitهای در دسترس برای هر کشور یکسان نیست.
* 🇪🇸 برخی کشورها ممکن است Exitهای معتبر کمتری داشته باشند.
* 🔄 در صورت نبود Exit معتبر، سیستم نباید IP مربوط به کشور دیگری را به‌عنوان Location انتخاب‌شده ثبت کند.

---

# 🐛 گزارش Bug

اگر با مشکل مواجه شدید، موارد زیر را همراه گزارش ارسال کنید:

```text
Country:
Server OS:
Error:
Public IP:
Expected Location:
Detected Location:
```

مثال:

```text
Country: Spain
Expected: ES
Detected: UA
```

---

# ⭐ Support

اگر پروژه برای شما مفید بود، با یک ⭐ روی Repository از پروژه حمایت کنید.

---

## 📜 License

این پروژه برای اهداف آموزشی و مدیریتی ارائه شده است.

استفاده و پیاده‌سازی آن باید مطابق قوانین سرویس‌دهنده، دیتاسنتر و قوانین محل استفاده باشد.
