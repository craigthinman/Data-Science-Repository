# Getting BeautifulSoup to work with html
import urllib.parse
from bs4 import BeautifulSoup, SoupStrainer

# For parsing
import re
import pandas

# To work with urls easier
import urllib
from urllib import request
import requests

# For upload later
import csv

# Retrieving the html from the website

search_link = 'https://www.census.gov/programs-surveys/popest.html'
r = requests.get(search_link)
raw_html = r.text
soup = BeautifulSoup(raw_html, 'html.parser')

all_links = soup.find_all('a')
print(f'Number of links pre processing: {len(all_links)}')

# Scrolling through the output relative links can be seen that we need to join to their base or else weblinks could be lost.
# The base of the links will be joined as follows
base = 'https://www.census.gov'

# Grabs all links absolute and relative
census_links_list = []
for link in soup.find_all('a'):
    x = link.get('href')
    census_links_list.append(x)

# Removing nulls
census_links_list = [item for item in census_links_list if item is not None]


# Making a new list with only links starting with https: + appending relative links with their base
census_links_list_v2 = []
for item in census_links_list:
    if item[:8] == 'https://':
        census_links_list_v2.append(item)
    # This would be the criteria for a relative link
    elif item[:8] != 'https://' and item[0] == '/':
        new_link = base + item
        census_links_list_v2.append(new_link)
    else:
        True


# Removing duplicates by creating a set from the list and handling the issue of lingering /'s
census_set = set()
for x in census_links_list_v2:
    if x[-1] == "/":
        new_item = x[:-1]
        census_set.add(new_item)
    else:
        census_set.add(x)


print(f'Number of links post processing: {len(census_set)}\n')


# Writing results to a csv

final_set = list(census_set)
final_census_list = sorted(final_set)

# Exporting results into a file
file = open('output.csv', 'w')

with file as export_file:
    csv_writer = csv.writer(file)
    csv_writer.writerow(final_census_list)
export_file.close()

print('Output file created\n\nList of weblinks scrapped:\n')

# Printing the final list
for row in final_census_list:
    print(row)
