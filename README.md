# KOReader.patches
Some of the patches I created for the default Coverbrowser in KOReader.
All these patches are tested on KOReader 2025.10 "Ghost" and works perfectly.

## 🞂 How to install a user patch ?
Please [check the guide here.](https://koreader.rocks/user_guide/#L2-userpatches)

## Screenshot of final look

<img width="632" height="840" alt="Screenshot of modificaitons" src="https://github.com/user-attachments/assets/c2261d66-c28e-4e3a-a4d8-07fb3b0b997b" />


## 🞂 2--rounded-corners.lua

<img width="480" height="191" alt="Rounded corners" src="https://github.com/user-attachments/assets/c52f7fe7-e519-422f-9321-65b9e5afebe2" />

This patch adds rounded corners to book covers in mosaic menu view.
Download the icons folder (bw/coloured) and place the icons in koreader/icons

## 🞂 2-faded-finished-books.lua

<img width="524" height="547" alt="Faded look of finished books" src="https://github.com/user-attachments/assets/82870826-f876-490e-b023-745a3b1f544e" />

This adds a faded look to the finished books. Adjust the fading amount to your liking by editing the file.

## 🞂 2-new-status-icons.lua

<img width="561" height="174" alt="Custom status icons in black and white" src="https://github.com/user-attachments/assets/4da6bebf-3519-4e68-890d-7590c8bce622" />

<img width="561" height="174" alt="Custom status icons in colour" src="https://github.com/user-attachments/assets/3f9bbe07-61ee-4e80-a4b9-5115948997ca" />

A set of new custom icons for displaying the status of a book (reading, abandonded, finished) in black and white and in colour.

## 🞂 2-pages-badge.lua

<img width="471" height="202" alt="Page number badge" src="https://github.com/user-attachments/assets/fd4efeb0-7ff2-4426-b61f-7027f176af6b" />


This patch adds the page number of a book to its cover on the bottom left as a small rounded badge. 

It parses the page number from the title of the file, in the following formats 'P(123)'. So make sure your book's title contains the page number.

Page number's font, color, backgroud color, border thickness, rounded corner radius can be adjusted to your liking in the .lua file.

## 🞂 2-progress-badge.lua

<img width="468" height="317" alt="Progress percentage" src="https://github.com/user-attachments/assets/ff393bd7-1f17-48f6-9749-6a09d349d2e2" />


This patch the progress percentage of a book as a badge in the top right corner of the cover. The badge should be copied to 'koreader/icons' from the downloaded icons folder.
