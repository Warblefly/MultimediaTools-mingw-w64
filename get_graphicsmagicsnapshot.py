#!/usr/bin/python

from bs4 import BeautifulSoup
import requests
import re

url = 'https://sourceforge.net/projects/graphicsmagick/files/graphicsmagick-snapshots/'

html_text = requests.get(url).text
soup = BeautifulSoup(html_text, "html.parser")
filename = soup.find_all(string=re.compile("GraphicsMagick-1.4.(?!.*asc)"))[0]
directory = filename[:-7]

print(url + filename + ";" + directory)


