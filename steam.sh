#!/bin/bash
# # # # # # # # # # # # # # 
#   get steam ip ranges   #
# # # # # # # # # # # # # # 

whois -h whois.radb.net -- '-i origin AS32590' | grep 'route:' | awk '{print $2}' | sort -u
