#!/bin/sh
######################################################
# 
# Purpose: Installation of pgRouting on Xubuntu 9.04
# Author:  Anton Patrushev <anton.patrushev@gmail.com>
#
######################################################
# Copyright (c) 2009 Open Geospatial Foundation
#
# Licensed under the GNU LGPL.
# 
# This library is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published
# by the Free Software Foundation, either version 2.1 of the License,
# or any later version.  This library is distributed in the hope that
# it will be useful, but WITHOUT ANY WARRANTY, without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU Lesser General Public License for more details, either
# in the "LICENSE.LGPL.txt" file distributed with this software or at
# web page "http://www.fsf.org/licenses/lgpl.html".
#

# About:
# =====
# This script will install pgRouting into Xubuntu 

# Running:
# =======
# sudo ./install_pgrouting.sh

TMP="/tmp/pgrouting_downloads"
INSTALL_FOLDER="$TMP/pgrouting"
POSTGIS_FOLDER="/usr/share/postgresql-8.3-postgis"
POSTLBS_FOLDER="/usr/share/postlbs"
BIN="/usr/bin"
USER_NAME="user"
USER_HOME="/home/$USER_NAME"

## Setup things... ##

# check required tools are installed
if [ ! -x "`which wget`" ] ; then
 echo "ERROR: wget is required, please install it and try again" 
 exit 1
fi

if [ ! -x "`which psql`" ] ; then
 echo "ERROR: PostgreSQL is required, please install it and try again" 
 exit 1
fi

# create tmp folders
mkdir $TMP
cd $TMP

# install libraries
apt-get install postgresql-server-dev-8.3
apt-get install build-essential cmake
apt-get install libboost-graph-dev
apt-get install libcgal*

apt-get autoremove

if [ -f "gaul-devel-0.1849-0.tar.gz" ]
then
 echo "gaul-devel-0.1849-0.tar.gz has already been downloaded."
else
 wget http://downloads.sourceforge.net/gaul/gaul-devel-0.1849-0.tar.gz?modtime=1114163427&big_mirror=0
fi
tar -xzf gaul-devel-0.1849-0.tar.gz
cd gaul-devel-0.1849-0/
./configure --disable-slang
make
sudo make install
sudo ldconfig

cd $TMP

# get pgRouting
if [ -f "pgRouting-1.03.tgz" ]
then
 echo "pgRouting-1.03.tgz has already been downloaded."
else
 wget http://files.postlbs.org/pgrouting/source/pgRouting-1.03.tgz
fi

# get sample data
if [ -f "sydney.tar.gz" ]
then
 echo "sydney.tar.gz has already been downloaded."
else
 wget http://files.postlbs.org/foss4g2009/sydney.tar.gz
fi

# unpack sample data
tar -xzf sydney.tar.gz -C $TMP

# unpack and compile pgRouting
tar -xzf pgRouting-1.03.tgz -C $TMP

cd $INSTALL_FOLDER

cmake -DWITH_TSP=ON -DWITH_DD=ON .
make
sudo make install

# create routing database
createdb -U postgres sydney
createlang -U postgres plpgsql sydney

cd ..

# add PostGIS functions
psql -U postgres -f $POSTGIS_FOLDER/lwpostgis.sql sydney
psql -U postgres -f $POSTGIS_FOLDER/spatial_ref_sys.sql sydney

# add pgRouting functions
psql -U postgres -f $POSTLBS_FOLDER/routing_core.sql sydney
psql -U postgres -f $POSTLBS_FOLDER/routing_core_wrappers.sql sydney
psql -U postgres -f $POSTLBS_FOLDER/routing_topology.sql sydney

# add pgRouting TSP functions
psql -U postgres -f $POSTLBS_FOLDER/routing_tsp.sql sydney
psql -U postgres -f $POSTLBS_FOLDER/routing_tsp_wrappers.sql sydney

# add pgRouting Driving Distance functions
psql -U postgres -f $POSTLBS_FOLDER/routing_dd.sql sydney
psql -U postgres -f $POSTLBS_FOLDER/routing_dd_wrappers.sql sydney

# add data to the database
psql -c "DROP TABLE geometry_columns" -U postgres sydney
psql -f schema.sql -U postgres sydney
psql -f sydney.sql -U postgres sydney

# testing pgRouting functions
psql -c "SELECT gid, AsText(the_geom) AS the_geom FROM dijkstra_sp_delta('sydney', 101, 114, 0.003)" -U postgres sydney
psql -c "SELECT gid, AsText(the_geom) AS the_geom FROM astar_sp_delta('sydney', 101, 114, 0.003)" -U postgres sydney
psql -c "SELECT gid, AsText(the_geom) AS the_geom FROM shootingstar_sp('sydney', 8, 24, 0.1, 'length', true, true)" -U postgres sydney
