#!/usr/bin/env python
# -*- python -*-
# Bockjoo Kim, Univ. Of Florida
#

__rcsid__   = "$Id: dcc.py.in,v 1.2 2005/03/31 20:21:55 coldfeet Exp $"

import getopt
import sys
import os
import xmlrpclib

# python /state/partition1/coldhead/services/external/apache2/htdocs/cmssoft/cic/scripts/cic_send_log.py --send /raid/osgpg/pg/app/cmssoft/cic/cic_project_arch.CMSSW_4_4_2_patch10.slc5_amd64_gcc434.log CMSSW_4_4_2_patch10 slc5_amd64_gcc434 pg.ihepa.ufl.edu

xmlrpcservice='http://oo.ihepa.ufl.edu:8080/OSG/services.php'

def cic_send_log_main():
    
    usage = """cic_send_log.py [--useservice=<URI>] [options [args]]
    OPTIONS
             Top level options:
             -h | --help | --usage
                  Print help
             --useservice=<services_url>
                  Invoke useservice method to switch to the requested service
                  This option should be followed by one of the Method options
             --services 
                  Lists available services

             Method options:
             
             --send log cmssw arch host
                  It stores the install log for cmssw and arch on host to the RPC service
             --sendciclog log host
                  It sends the cic execution log on host to the RPC service
    """
    ## process source and dest args
    try:
        opts, args = getopt.getopt(sys.argv[1:], "h:", ["help", "usage","services","useservice=","send","sendciclog"])
    except getopt.GetoptError, what:
        print "GetOpt error:", what
        print usage
        sys.exit(1)
        
    #server=xmlrpclib.Server(xmlrpcservice)
    #server=None
    ## process options
    service=0
    for opt, arg in opts:
        if opt == "--useservice":
            server=xmlrpclib.Server(arg)
            service=1
    #print "sys.argv len ",len(sys.argv)
    if service==0 :
       if len(sys.argv) < 2 :
          print usage
          sys.exit(0)
    elif service==1 :
       if len(sys.argv) < 3 :
          print usage
          sys.exit(0)
    
    if service == 0 :
       if xmlrpcservice == '@@services_url@@' :
           print "congure service or use option --useservice"
           sys.exit(1)
       server=xmlrpclib.Server(xmlrpcservice)
    
   
    for opt, arg in opts:
            
        if opt in ("-h", "--help", "--usage"):
            print usage
            sys.exit(0)
        if opt == "--send":
            thefile=args[0]
            cmssw=args[1]
            arch=args[2]
            thesite=args[3]
            thestring=''
            try:
               f = open (thefile, 'r')
               thestring = f.read()
               f.close()
            except IOError:
               print "cic_send_log Failed to open",thefile
            #print "thestring ",thestring
            print server.stringecho(thestring,thefile,cmssw,arch,thesite)
        elif opt == "--sendciclog":
            thefile=args[0]
            thesite=args[1]
            thestring=''
            try:
               f = open (thefile, 'r')
               thestring = f.read()
               f.close()
            except IOError:
               print "cic_send_log Failed to open",thefile
            #print "thestring ",thestring
            print "thefile ",thefile
            print server.sendciclog(thestring,thesite)
        elif opt == "--services":
            print "default : --useservice=http://oo.ihepa.ufl.edu:8080/OSG/services.php"
        #else:
        #    print usage
        
    #    sys.exit(0)
    
       



if __name__ == '__main__':
    cic_send_log_main()
