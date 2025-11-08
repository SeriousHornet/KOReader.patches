# KOReader.patches

Some of the patches I created for the default Coverbrowser in KOReader and Project: Title plugin.

**NOTE: Patches with 'for-PT' in their filenames are only for Project: Title plugin. For coverbrowser download the ones normal ones without 'for-PT'.**

All these patches are tested on KOReader 2025.10 "Ghost" and Project: Title v3.5 and works perfectly.

## 🞂 How to install a user patch ?
Please [check the guide here.](https://koreader.rocks/user_guide/#L2-userpatches)

## Screenshot of final look

<img width="720" height="990" alt="Overall Look" src="https://github.com/user-attachments/assets/890b7288-31d1-4e44-82d6-399eda54e112" />


## 🞂 2--rounded-corners.lua

<img width="720" height="325" alt="Rounded corners to book covers" src="https://github.com/user-attachments/assets/ed550b96-a4dc-4354-9e91-c38195d9596f" />

This patch adds rounded corners to book covers in mosaic menu view.

Download the icons `rounded.corner.bl.svg`, `rounded.corner.tl.svg`, `rounded.corner.br.svg` and `rounded.corner.tr.svg` from my icons folder and place the icons in `koreader/icons` in your e-reader.


## 🞂 2-faded-finished-books.lua

<img width="720" height="325" alt="Faded look to finished books" src="https://github.com/user-attachments/assets/a7b3903c-51a2-439d-a990-296871325148" />

This adds a faded look to the finished books. Adjust the fading amount to your liking by editing the .lua file.


## 🞂 2-new-status-icons.lua

<img width="561" height="174" alt="Custom status icons in black and white" src="https://github.com/user-attachments/assets/4da6bebf-3519-4e68-890d-7590c8bce622" />

<img width="561" height="174" alt="Custom status icons in colour" src="https://github.com/user-attachments/assets/3f9bbe07-61ee-4e80-a4b9-5115948997ca" />


A set of new custom icons for displaying the status of a book (reading, abandonded, finished) in black and white and in colour.

Just copy the respective `dogear.abandoned.svg`, `dogear.reading.svg` and `dogear.complete.svg` to your e-reader's `koreader/icons` folder.


## 🞂 2-pages-badge.lua

<img width="720" height="143" alt="Pages Badge" src="https://github.com/user-attachments/assets/24cd6798-1615-4276-8ed6-d631f0016202" />


This patch adds the page number of a book to its cover on the bottom left as a small rounded badge. 

**IMPORTANT:** This patch parses the page number from Project Title's database or from the title of the file, in the following formats `P(123)` or `p(123)`. So make sure your book's title contains the page number in this format if you are using coverbrowser. (I'll work on improving page detection mechanism for coverbrowser soon)

**NOTE:** Page number's font size, color, backgroud color, border thickness, rounded corner radius can be adjusted to your liking in the .lua file.


## 🞂 2-progress-badge.lua

<img width="720" height="143" alt="Progress badge" src="https://github.com/user-attachments/assets/04b70470-d8a2-4fe8-b6f2-d981630bcf3f" />


This patch adds the progress percentage of a book as a badge in the top right corner of the cover.

Copy the `2-progress-badge.lua` to `koreader/patches` and copy the `progress.badge.svg` to `koreader/icons` folder of your e-reader. You can choose coloured or bw icons based on your device/liking.

**NOTE:** Progress badge's size, location, text size can be adjusted to your liking in the .lua file.

## 🞂 2-series-indicator.lua

<img width="720" height="143" alt="Series indicator" src="https://github.com/user-attachments/assets/6d2a812e-2793-474f-8e08-e1a6e731616b" />

This patch adds a small rectangular indicator to the top right of the book cover to mean that the book is part of a series. 

For this to work seamlessly I suggest to uncheck the "Show hint for books with description" from "Settings 🞂 Mosaic and detailed list settings 🞂 Display hints" so it looks clean.

## 🞂 2-new-progress-bar-for-PT.lua

<img width="480" height="150" alt="image" src="https://github.com/user-attachments/assets/8ccd0634-3135-44c9-a939-0cad2957da01" />

This patch adds a clean rounded rectangular progress bar to the bottom of the cover. This disables the default progress bar of Project: Title. 

For this to work as intended, it is suggested to uncheck all options in "Project: Title Settings 🞂 Advanced settings 🞂 Book display 🞂" so they don't clash.

## 2-collections-star-for-PT.lua

This adds a star in a black circle to left top corner of the book to indicate that the book is part of a collection

---

Credits to @joshuacant, @sebdelsol and u/medinauta as I borrowed much of their code and structure.

