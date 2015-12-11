#!/usr/bin/python

from __future__ import print_function, unicode_literals

import json
import requests
import time
import sys
import os

#################################################################################################
################        CONFIGURATION
#################################################################################################

token_id = 'xxxxxxxxxxxxxxx'
token_key = 'xxxxxxxxxxxxxxx'
end_point = 'https://opentsdb.iot.runabove.io/api/put'

#################################################################################################
################        END CONFIGURATION
#################################################################################################

timestamp=int (time.time())


if len(sys.argv) ==1:
    print ("*erreur")
    sys.exit(0)

else:
    metric =sys.argv[1]
    tag =sys.argv[2]
    key =sys.argv[3]
    valeur =float(sys.argv[4])



data = [
    {
        'metric': metric,
        'timestamp': timestamp,
        'value': valeur,
        'tags': {
            tag: key
        }
    }
]
print (data)


try:
    # Send request and fetch response
    response = requests.post(end_point, data=json.dumps(data),
                             auth=(token_id, token_key))

    # Raise error if any
    response.raise_for_status()

    # Print the http response code on success
    print('Send successful\nResponse code from server: {}'.
          format(response.status_code))

except requests.exceptions.HTTPError as e:
    print('HTTP code is {} and reason is {}'.format(e.response.status_code,
                                                    e.response.reason))

