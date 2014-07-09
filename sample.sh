# Idea: to validate data in a text file, we first load it to a data table
# then use the validation utilities to validate the table
#
# The followings are performed by this script:
#     * 1 Load raw text files into corresponding SQL tables
#     * 2 Perform validation
#     * 3 Generate reports
#
# @author NghiPM
# @date May 2014

###################################################################################
# SET UP ENVIRONMENT VARIABLES
###################################################################################
# Instead of passing PostgreSQL credentials as parameters to every validation command,
# you can set the corresponding environment variables which can be used by the those commands
export HOST="localhost"
export USERNAME="postgres"
export PASSWORD="postgres"
export DATABASE="northeast_georgia"
export LISTEN=5432

# Input file paths and corresponding table names
FVENDOR="VendorMaster.csv"
VENDOR="vendors"

FITEM="ItemMaster.csv"
ITEM="items"

# Specify a temp folder for writing temporary outputs
# Specify the path to the output summary report
TMP="/tmp"
REPORT="/tmp/report.xls"

###################################################################################
# STEP 1 - Load raw text files into corresponding SQL tables
###################################################################################

# Load data from VendorMaster.csv to the corresponding vendors table
# and from ItemMaster.csv to items table.
# Note: instead of using iload utility,you can use the PSQL COPY of PostgreSQL
iload -i "$FVENDOR" -t "$VENDOR" -f csv
iload -i "$FITEM" -t "$ITEM" -f csv

###################################################################################
# STEP 2 - Perform validation, log the results to an additional field
###################################################################################
# validate the vendors table
ivalidate --table=$VENDOR --log-to=validation_errors \
       --not-null="vendor_code" \
       --not-null="vendor_name" \
       --unique="vendor_code" \
       --unique="vendor_name" \
       --match="vendor_code/[a-zA-Z0-9]/" \
       --match="vendor_name/[a-zA-Z0-9]/" \
       --consistent-by="vendor_code|vendor_name" \
       --consistent-by="vendor_name|vendor_code" \
       --consistent-by="country_code|country_name" \
       --consistent-by="country_name|country_code"

# validate the items table
ivalidate --table=$ITEM \
       --log-to=validation_errors \
       --not-null="item_id" \
       --match="item_id/[a-zA-Z0-9]/" \
       --not-null="item_desc" \
       --match="item_desc/[a-zA-Z0-9]/" \
       --not-null="item_uom" \
       --not-null="default_uom" \
       --not-null="item_price" \
       --not-null="item_qoe" \
       --not-null="corp_id" \
       --not-null="corp_name" \
       --not-null="vendor_code" \
       --not-null="vendor_name" \
       --not-null="mfr_number" \
       --not-null="mfr_name" \
       --not-null="active" \
       --match="corp_id/[a-zA-Z0-9]/" \
       --match="corp_name/[a-zA-Z0-9]/" \
       --match="vendor_code/[a-zA-Z0-9]/" \
       --match="vendor_name/[a-zA-Z0-9]/" \
       --match="mfr_number/[a-zA-Z0-9]/" \
       --match="mfr_name/[a-zA-Z0-9]/" \
       --match="active/^(1|2|3|A|I)$/" \
       --consisten-by="corp_id|corp_name" \
       --consisten-by="corp_name|corp_id" \
       --consisten-by="vendor_code|vendor_name" \
       --consisten-by="vendor_name|vendor_code" \
       --cross-reference="vendor_code|$VENDOR.vendor_code" \
       --cross-reference="vendor_name|$VENDOR.vendor_name"

###################################################################################
# Step 3 - Generate summary report
###################################################################################
# After the validation step above, an additional field named validation_errors
# is added to every table. In case the record does not pass a validation creterion, a corresponding error shall be logged to this field
# One record may have more than one error logged
# 
# You can simply look at the validation_errors field to see errors associated to a record
# 
# Just to make a MORE comprehensive report, we can:
#    1 Create a summary table which tells us how many errors found, how many records associated with each...
#    2 Extract the first 1000 sample records for every error
#    3 Put all together into one single Excel report


# 1) Create error summary report table and write to /tmp/summary.csv
# This can be done using the iexport utility which can generate a CSV file from a data table or from a custom query
# Run iexport --help for more information
iexport --output="$TMP/summary.csv" -f csv --no-quote-empty --quotes --headers \
        --query="(select '$FVENDOR' as input_file, unnest(string_to_array(validation_errors, ' || ')) as error, count(*), round((count(*) * 100)::numeric / (select count(*) from $VENDOR), 2)::varchar || '%' as percentage from $VENDOR group by error order by error) union
                 (select '$FITEM' as input_file, unnest(string_to_array(validation_errors, ' || ')) as error, count(*), round((count(*) * 100)::numeric / (select count(*) from $ITEM), 2)::varchar || '%' as percentage from $ITEM group by error order by error)"

# Export the first 1000 records of every error in the items table
# Write the results to /tmp/items.csv
iexport --table=$VENDOR --output="$TMP/$VENDOR.csv" -f csv --no-quote-empty --quotes --headers \
        --query="select * from (select ROW_NUMBER() OVER (PARTITION BY error) AS group_index, * 
                 FROM ( select unnest(string_to_array(validation_errors, ' || ')) as error, * from
                 $VENDOR order by id  ) as main) as tmp
                 where group_index <= 1000" \
        --exclude="id, validation_errors, group_index"

# 2) Export the first 1000 records of every error in the vendors table
# Write the results to /tmp/vendors.csv
iexport --table=$ITEM --output="$TMP/$ITEM.csv" -f csv --no-quote-empty --quotes --headers \
        --query="select * from (select ROW_NUMBER() OVER (PARTITION BY error) AS group_index, * 
                 FROM ( select unnest(string_to_array(validation_errors, ' || ')) as error, * from
                 $ITEM order by id  ) as main) as tmp
                 where group_index <= 1000" \
        --exclude="id, validation_errors, group_index"

# 3) Put the above 3 CSV files into one Excel file /tmp/report.xls
# This can be done using imerge which takes a list of CSV files put them to corresponding sheets
# of one single Excel file
imerge --output=$REPORT \
       --input="Summary:$TMP/summary.csv" \
       --input="$FVENDOR:$TMP/$VENDOR.csv" \
       --input="ItemMaster:$TMP/$ITEM.csv"

# CLEANUP
# Remember to drop the temporary tables you create (items and vendors)

