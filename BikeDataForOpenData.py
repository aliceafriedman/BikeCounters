#!/usr/bin/env python
# coding: utf-8

# # NYC Automated Bicycle Counts
# ## Script for Open Data Pull
# July 30, 2020; revised October 8, 2020
# Alice Friedman
# 
# This code will download data from the EcoCounter API and write to CSV for upload to Open Data NYC Bike Counters & Bike Counts pages. .
# 
# Data on each bike counter and the raw counts are stored in separate tables.
# 
# For the purpose of Open Data we pull data through the end of the previous month.
# 
# References:
# * [Eco-Counter API Documentation](http://eco-test2.com/apidoc/wso2/apidoc.html)
# * [NYC Bicycle Counts on Open Data](https://data.cityofnewyork.us/Transportation/Bicycle-Counts/uczf-rk3c)
# * [NYC Bicycle Counters on Open Data](https://data.cityofnewyork.us/Transportation/Bicycle-Counters/smn3-rzf9)
# 

# ## Setup
# 
# The below codes authorized the user to pull data from the Eco-Counter API site with endpoint [https://apieco.eco-counter-tools.com/api](https://apieco.eco-counter-tools.com/api).
# 
# The code requires use of a password and user name stored in a file called 'pw.json' to be stored in the same folder as this script. For questions or access to the pw (for DOT employees only), please email [Alice Friedman](mailto:afriedman@dot.nyc.gov) or [Patrick Kennedy](mailto:pkennedy@dot.nyc.gov) in the NYC DOT Bicycle Unit

# In[22]:


# make sure to install these packages before running:
import urllib.request, json, requests
import pandas as pd
from datetime import datetime
import os


# In[2]:


#username and pw are stored in a seperate file
with open('pw.json') as json_file:
    f = json.load(json_file)
user = f['user']
pw = f['pw']

token_headers = {
    'Authorization': 'Basic MWJRWWJPdUdOMXdsaktNMXNKNmZtOEdLczNvYTpINW9fNF8yQWtNOUc0SlRHa1JWakdDS0NKQTBh, \
     Content-Type: application/x-www-form-urlencoded',
}

login_data = {
  'grant_type': 'password',
  'username': user,
  'password': pw
}

response = requests.post('https://apieco.eco-counter-tools.com/token', headers=token_headers, data=login_data)
token_dict = json.loads(response.content.decode('utf-8'))
auth = 'Bearer '+ token_dict['access_token']

headers = {
    'Accept': 'application/json',
    'Authorization': auth,
}


# ## Create output folder with date
# Outputs will be stored in a new folder with the date for ease.

# In[23]:


now = str(datetime.now().date())
folder = 'output_' + now +'/'

if not os.path.exists(folder):
    os.makedirs(folder)


# ## Locations table
# 
# Download sites, drop irrelevant columns, and write to CSV. 
# 
# The resulting CSV tables should be posted to [NYC Bicycle Counters on Open Data](https://data.cityofnewyork.us/Transportation/Bicycle-Counters/smn3-rzf9).

# In[3]:


#get locations are called 'sites'
response = requests.get('https://apieco.eco-counter-tools.com/api/1.0/site', headers=headers)
locations_raw = pd.DataFrame(json.loads(response.content.decode('utf-8')))
locations_raw.head(3)


# In[15]:


locations = locations_raw.drop(['channels', 'userType', 'photos'], axis=1)
locations = locations.rename(columns={"id":"site"})
print(locations.head())


# Write to file, with date script run in filename.

# In[24]:


filename = folder + 'bike_counters.csv'
locations.to_csv(filename)


# ## Bicycle Counts from API
# 
# The below code loops thought locations in the locations table above to download raw bike count data. 
# 
# As locations are added over time, this will therefore automatically include new locations as they come online.

# In[17]:


def to_file(df, filename):

    #filter counts before a certain date
    thismonth = datetime.today().month
    thisyear = datetime.today().year
    lastdate = datetime(thisyear, thismonth, 1)
    counts_to_post = df[pd.to_datetime(df['date'], infer_datetime_format=True) < lastdate]
    counts_to_post.to_csv(filename)


# In[18]:


def load_data_EcoCounter_API(site, step):
    ###GET Request to use token to download data
    end = 'https://apieco.eco-counter-tools.com/api/1.0/data/site/'
    url = end + str(site) + '?step='+ step
    response = requests.get(url, headers=headers)
    #store response as dataframe
    df = pd.DataFrame(json.loads(response.content.decode('utf-8')))    
    #add site ID to dataframe
    df = df.assign(site=site)
    return (df)

#the second function loops through a list of locations 
#and returns a single dataframe with id in column 'site'
#options for step include 15m, day, month, and year
def load_all(locations, step):
    dataList = []
    step=step
    
    for site in locations['site']:
        print("loading data for location " + str(site))
        df= load_data_EcoCounter_API(site, step)
        dataList.append(df)
        #save individual files by location
        filename = folder + "bike_counts_loc_" + str(site) + now + ".csv"
        to_file(df, filename)
    
    print("Done.")
    
    #return complete list
    df_all=pd.concat(dataList)
    return(df_all)


# In[19]:


counts=load_all(locations, '15m')


# In[ ]:




