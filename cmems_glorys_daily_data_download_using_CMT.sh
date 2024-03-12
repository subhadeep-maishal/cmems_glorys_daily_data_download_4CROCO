#!/bin/bash

# User-defined date range for Ocean forcing
YEAR_START=2018
MONTH_START=01
DAY_START=01

YEAR_END=2018
MONTH_END=12
DAY_END=01

# Output directory (user need to define)
outdir="/scratch/20cl91p02/CROCO_TOOL_FIX/Oforc_glory_mercator"

# Product and dataset IDs
serviceId="GLOBAL_MULTIYEAR_PHY_001_030-TDS"
productId="cmems_mod_glo_phy_my_0.083_P1D-m"

# Coordinates
lon=(-180 180)   #longitude
lat=(-80 90)     #latitude

# Variables need for Ocean forcing
variable=("zos" "uo" "vo" "thetao" "so")

# Depth range
defaultDepthRange="0.493 5727.918"
depthRange=""

# Parse command line options
while getopts ":d:" opt; do
  case $opt in
    d)
      depthRange="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# If depth range is not provided, use the default values
if [ -z "$depthRange" ]; then
  depthRange="$defaultDepthRange"
fi

#copernicus-marine login Id and Password (user need to define)
export CM_USERNAME="xxxxxxx"
export CM_PASSWORD="xxxxxxx"
PREFIX="mercator"

# Function to check if a year is a leap year or not
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

        # Temporary directory for daily files (when user dont need to define)
        tempdir="$outdir/temp_daily_files"
        mkdir -p $tempdir
        depthRangeOption="--depth $depthRange"

        # Download daily data (main for copernicus-marine subset)
        while [[ "$startDate" != "$endDate" ]]; do
            echo "=============== Date: $startDate ===================="

            command="copernicus-marine subset --username $CM_USERNAME --password $CM_PASSWORD -i $productId \
            -v ${variable[0]} -v ${variable[1]} -v ${variable[2]} -v ${variable[3]} -v ${variable[4]} \
            -x ${lon[0]} -X ${lon[1]} -y ${lat[0]} -Y ${lat[1]} \
            -t \"$startDate\" -T \"$startDate\" \
            --minimum-depth $(echo $depthRange | awk '{print $1}') \
            --maximum-depth $(echo $depthRange | awk '{print $2}') \
            --force-download -o $tempdir -f raw_motu_${PREFIX}_$(date -d "$startDate" +%Y-%m-%d).nc" 
            
            echo -e "$command \n============="
            eval "$command"

            startDate=$(date -d "$startDate + $addDays days" +%Y-%m-%d)
        done

        # Concatenate daily files into a monthly file (user can add this section after the loop)
        monthly_file="$outdir/raw_motu_${PREFIX}_${year}_$month.nc"
        #ncrcat -O $tempdir/raw_motu_${PREFIX}_*.nc $monthly_file
        cp -R $monthly_file ../
        # Remove temporary daily files
        #rm -rf $tempdir

        echo "=========== Monthly file created: $monthly_file ==========="
    done
done

echo "=========== Download and concatenation completed! And Have a good day! if there have CROCO==========="
