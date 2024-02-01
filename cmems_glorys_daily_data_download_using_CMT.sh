#!/bin/bash

# Further Information:   
# http://www.croco-ocean.org
#  
# This file is part of CROCOTOOLS
#
# CROCOTOOLS is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published
# by the Free Software Foundation; either version 2 of the License,
# or (at your option) any later version.
#
# CROCOTOOLS is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA  02111-1307  USA
#
# Author : S. Maishal
# subhadeepmaishal@kgpian.iitkgp.ac.in


# User-defined date range
# pip install copernicus-marine-client
YEAR_START=2018
MONTH_START=03
DAY_START=1

YEAR_END=2018
MONTH_END=05
DAY_END=01

# Output directory
outdir="/scratch/20cl91p02/CROCO_TOOL_FIX"

# Product and dataset IDs
serviceId="GLOBAL_MULTIYEAR_PHY_001_030-TDS"
productId="cmems_mod_glo_phy_my_0.083_P1D-m"

# Coordinates
lon=(50 100)   #longitude
lat=(-30 30)     #latitude

# Variables
variable=("zos" "uo" "vo" "thetao" "so")

#copernicus-marine login
export CM_USERNAME="xxxx"
export CM_PASSWORD="xxxx"
PREFIX="mercator"

# Function to check if a year is a leap year
is_leap_year() {
    year=$1
    if [ $((year % 4)) -eq 0 ] && [ $((year % 100)) -ne 0 ] || [ $((year % 400)) -eq 0 ]; then
        return 0  # Leap year
    else
        return 1  # Not a leap year
    fi
}

# Loop over years and months
for year in $(seq $YEAR_START $YEAR_END); do
    for month in $(seq -w $MONTH_START $MONTH_END); do
        # Set the last day of the month based on the current month and year
        last_day=$(cal $month $year | awk 'NF {DAYS = $NF}; END {print DAYS}')
        
        # Handle leap year
        if [ $month -eq 2 ] && is_leap_year $year; then
            last_day=29
        fi
        
        # Date initialization
        startDate=$(date -d "$year-$month-$DAY_START" +%Y-%m-%d)
        endDate=$(date -d "$year-$month-$last_day" +%Y-%m-%d)

        # Time step
        addDays=1

        endDate=$(date -d "$endDate + $addDays days" +%Y-%m-%d)

        # Temporary directory for daily files
        tempdir="$outdir/temp_daily_files"
        mkdir -p $tempdir

        # Download daily data
        while [[ "$startDate" != "$endDate" ]]; do
            echo "=============== Date: $startDate ===================="

            command="copernicus-marine subset --username $CM_USERNAME --password $CM_PASSWORD -i $productId \
            -v ${variable[0]} -v ${variable[1]} \
            -x ${lon[0]} -X ${lon[1]} -y ${lat[0]} -Y ${lat[1]} \
            -t \"$startDate\" -T \"$startDate\" \
            --force-download -o $tempdir -f raw_motu_${PREFIX}_$(date -d "$startDate" +%Y-%m-%d).nc" 
            
            echo -e "$command \n============="
            eval "$command"

            startDate=$(date -d "$startDate + $addDays days" +%Y-%m-%d)
        done

        # Concatenate daily files into a monthly file
        monthly_file="$outdir/raw_motu_${PREFIX}_${year}_$month.nc"
        ncrcat -O $tempdir/raw_motu_${PREFIX}_*.nc $monthly_file

        # Remove temporary daily files
        rm -rf $tempdir

        echo "=========== Monthly file created: $monthly_file ==========="
    done
done

echo "=========== Download and concatenation completed! ==========="
