#!/bin/bash

# SHARED VARIABLES
# ---------------------------------------------------------------------------------
# Database to store data tables
ORGNAME="tiff20140805"

# ENV variables used by the validation command
export HOST="localhost"
export USERNAME="postgres"
export PASSWORD="postgres"
export DATABASE="$ORGNAME"
export LISTEN=7432

# Create temporary output folder
OUTPUT_DIR="/tmp/$ORGNAME" && test -e $OUTPUT_DIR || mkdir $OUTPUT_DIR

# Input files and correspondings names
FCONTRACTO="ContractMaster.csv"
FVENDOR="VendorMaster.csv"
FITEM="ItemMaster.csv"
FINVOICE="InvoiceHistory.csv"
FMFR="MfrMaster.csv"
FPO="PurchaseOrder.csv"
FUSER="User.csv"
FLOCATION="Location.csv"
FITEMCOST="ItemCostCenterAcctExceptions.csv"
FREQ="ReqHistoryLoad.csv"
FGL="GLAccount.csv"
FINVENTORY="Inventory.csv"
FULPR="UserAndLocationProfile.csv"
FLPR="LocationProfile.csv"

CONTRACTO="contracts"
VENDOR="vendors"
ITEM="items"
INVOICE="invoices"
MFR="manufacturers"
PO="purchase_orders"
USER="users"
LOCATION="locations"
ITEMCOST="item_costs"
REQ="reqs"
GL="gls"
INVENTORY="inventory"
ULPR="user_location_profiles"
LPR="location_profiles"

# Standard UOM for reference
FUOMSTD="stduom.txt"
UOMSTD="uomstd"

# ---------------------------------------------------------------------------------
# LOAD
# ---------------------------------------------------------------------------------
# Sanitize input files
#isanitize --strip-newline --remove=65279 "$FCONTRACTO" "$FVENDOR" "$FITEM" "$FINVOICE" "$FMFR" "$FPO" \
#                                         "$FTMPL" "$FUSER" "$FITEMEXPO" "$FUSEREQ" "$FLOCATION" "$FITEMCOST" "$FREQ" \
#                                         "$FGL" "$FUSERCOST" "$FINVENTORY" "$FUSERCREATEREQ"

# Load
iload -i "$FCONTRACTO" -t "$CONTRACTO" -f csv
iload -i "$FVENDOR" -t "$VENDOR" -f csv
iload -i "$FITEM" -t "$ITEM" -f csv
#iload -i "$FINVOICE" -t "$INVOICE" -f csv
iload -i "$FMFR" -t "$MFR" -f csv
iload -i "$FPO" -t "$PO" -f csv
iload -i "$FUSER" -t "$USER" -f csv
iload -i "$FLOCATION" -t "$LOCATION" -f csv
iload -i "$FREQ" -t "$REQ" -f csv
iload -i "$FGL" -t "$GL" -f csv
iload -i "$FINVENTORY" -t "$INVENTORY" -f csv
iload -i "$FULPR" -t "$ULPR" -f csv
iload -i "$FLPR" -t "$LPR" -f csv

# Load UOM STANDARD for reference
iload -i "$FUOMSTD" -t "$UOMSTD" -f csv

# ---------------------------------------------------------------------------------
# INDEXING (for speeding up validation queries)
# ---------------------------------------------------------------------------------
ipatch -q "drop index if exists items_item_id_index; create index items_item_id_index on $ITEM(item_id)"
ipatch -q "drop index if exists pos_item_id_index; create index pos_item_id_index on $PO(item_id)"
ipatch -q "drop index if exists gls_corp_acct_no_index; create index gls_corp_acct_no_index on $GL(corp_acct_no)"
ipatch -q "drop index if exists gls_corp_acct_name_index; create index gls_corp_acct_name_index on $GL(corp_acct_name)"
ipatch -q "drop index if exists gls_cc_acct_no_index; create index gls_cc_acct_no_index on $GL(cc_acct_no)"
ipatch -q "drop index if exists gls_cc_acct_name_index; create index gls_cc_acct_name_index on $GL(cc_acct_name)"
ipatch -q "drop index if exists locations_name_index; create index locations_name_index on $LOCATION(name)"

# ---------------------------------------------------------------------------------
# Some adjustment
# ---------------------------------------------------------------------------------
ipatch -q "
-- Normalize values
UPDATE $ITEM set active = '1' where active = 'Y';
UPDATE items set active = '3' where active = 'N';
"

ipatch -q "
-- ADD EMAIL COLUMN
ALTER TABLE $USER ADD COLUMN email VARCHAR;
UPDATE $USER SET email = LOGIN_ID;
"

ipatch -q "
-- FIX ISSUE WITH linebreak 
update items set vendor_item_id = (string_to_array(regexp_replace(replace(vendor_item_id, E'\r\n', ' '), '\s+', ' ', 'g'), ' '))[1]
where vendor_item_id like E'%\r\n%';
update purchase_orders set vendor_item_id = (string_to_array(regexp_replace(replace(vendor_item_id, E'\r\n', ' '), '\s+', ' ', 'g'), ' '))[1]
where vendor_item_id like E'%\r\n%';
update purchase_orders set vendor_item_id = (string_to_array(regexp_replace(replace(vendor_item_id, E'\n', ' '), '\s+', ' ', 'g'), ' '))[1]
where vendor_item_id like E'%\n%';
"

ipatch -q "
-- Normalize DATE
UPDATE $PO SET po_date = to_char(to_date(po_date, 'MM/DD/YYYY'), 'YYYY-MM-DD')
WHERE po_date IS NOT NULL AND po_date != '';
UPDATE $CONTRACTO SET contract_start = to_char(to_date(contract_start, 'MM/DD/YYYY'), 'YYYY-MM-DD')
WHERE contract_start like '%/%/%';
UPDATE $CONTRACTO SET contract_end = to_char(to_date(contract_end, 'MM/DD/YYYY'), 'YYYY-MM-DD')
WHERE contract_end like '%/%/%';

-- ADD MORE EMPTY FIELD (for validation)
-- ALTER TABLE $LOCATION ADD COLUMN corp_id varchar;

-- FILL EMPTY FIELDS WITH DEFAULT VALUE
UPDATE $LOCATION SET ship_to_ind = 'N' WHERE ship_to_ind IS NULL OR LENGTH(trim(ship_to_ind)) = 0;
UPDATE $LOCATION SET bill_to_ind = 'N' WHERE bill_to_ind IS NULL OR LENGTH(trim(bill_to_ind)) = 0;
UPDATE $LOCATION SET stockless_ind = 'N' WHERE stockless_ind IS NULL OR LENGTH(trim(stockless_ind)) = 0;
"
       
# Convert A2A2A2 to A2-A2-A2
# Manual check and comment out the following to speed up validating
# @todo IEVAL performance is very poor, avoid using it (use IPATCH instead) unless there is no better way
ieval -t $GL --eval="
  if item.corp_acct_fmt && item.corp_acct_fmt[/^[A-Z][0-9][A-Z][0-9][A-Z][0-9]$/]
    item.corp_acct_fmt = item.corp_acct_fmt.unpack('a2a2a2').join('-')
  end
"

# ---------------------------------------------------------------------------------
# VALIDATE
# ---------------------------------------------------------------------------------
# validate VENDORS
ivalidate --case-insensitive --pretty -t $VENDOR \
       --log-to=validation_errors \
       --not-null="vendor_code" \
       --not-null="vendor_name" \
       --unique="vendor_code, vendor_name" \
       --match="vendor_code/[a-zA-Z0-9]/" \
       --match="vendor_name/[a-zA-Z0-9]/" \
       --consistent-by="vendor_code|vendor_name" \
       --consistent-by="vendor_name|vendor_code" \
       --consistent-by="country_code|country_name" \
       --consistent-by="country_name|country_code"
       
# validate MANUFACTURERS
ivalidate --case-insensitive --pretty -t $MFR \
       --log-to=validation_errors \
       --not-null="mfr_number" \
       --not-null="mfr_name" \
       --unique="mfr_number, mfr_name" \
       --match="mfr_number/[a-zA-Z0-9]/" \
       --match="mfr_name/[a-zA-Z0-9]/" \
       --consistent-by="mfr_name|mfr_number" \
       --consistent-by="mfr_number|mfr_name" \
       --consistent-by="country_code|country_name" \
       --consistent-by="country_name|country_code"

# validate GL
ivalidate --case-insensitive --pretty -t $GL \
       --log-to=validation_errors \
       --not-null=corp_acct_no \
       --match="corp_acct_no/[a-zA-Z0-9]/" \
       --not-null=corp_acct_name \
       --match="corp_acct_name/[a-zA-Z0-9]/" \
       --not-null=corp_acct_fmt \
       --match="corp_acct_fmt/^[A-Z][0-9]-[A-Z][0-9]-[A-Z][0-9]$/" \
       --not-null=cc_acct_no \
       --match="cc_acct_no/[a-zA-Z0-9]/" \
       --not-null=cc_acct_name \
       --match="cc_acct_name/[a-zA-Z0-9]/" \
       --not-null=cc_acct_type \
       --match="cc_acct_type/^(1|2|3|4|5|Asset|Liability|Equity|Income\sStatement|Expense|Income)$/" \
       --not-null=exp_acct_no \
       --match="exp_acct_no/[a-zA-Z0-9]/" \
       --not-null=exp_acct_name \
       --match="exp_acct_name/[a-zA-Z0-9]/" \
       --consistent-by="corp_acct_no|corp_acct_name" \
       --consistent-by="corp_acct_name|corp_acct_no" \
       --consistent-by="exp_acct_no|corp_acct_no, corp_acct_name, cc_acct_no, cc_acct_name, exp_acct_name" \
       --consistent-by="exp_acct_name|corp_acct_no, corp_acct_name, cc_acct_no, cc_acct_name, exp_acct_no" \
       --consistent-by="cc_acct_no|corp_acct_no, corp_acct_name, cc_acct_name, exp_acct_no, exp_acct_name" \
       --consistent-by="cc_acct_name|corp_acct_no, corp_acct_name, cc_acct_no, exp_acct_no, exp_acct_name" \
       --not-null=exp_acct_type \
       --match="exp_acct_type/^(1|2|3|4|5|Asset|Liability|Equity|Income\sStatement|Expense|Income)$/"
       
# validate LOCATION
ivalidate --case-insensitive --pretty -t $LOCATION \
       --log-to=validation_errors \
       --not-null="loc_id" \
       --match="loc_id/[a-zA-Z0-9]/" \
       --not-null="name" \
       --match="name/[a-zA-Z0-9]/" \
       --not-null=facility_code \
       --match="facility_code/[a-zA-Z0-9]/" \
       --not-null=facility_desc \
       --match="facility_desc/[a-zA-Z0-9]/" \
       --match="ship_to_ind/^(Y|N|y|n)$/" \
       --match="bill_to_ind/^(Y|N|y|n)$/" \
       --match="stockless_ind/^(Y|N|y|n)$/" \
       --not-null="loc_type" \
       --match="loc_type/^(C|S|LOC_TYPE_SUPPLY|LOC_TYPE_CONSUME)$/" \
       --rquery="(loc_type ~* '^(LOC_TYPE_SUPPLY|S)$' and (corp_acct_no is null or corp_name is null or corp_id is null)) -- either corp id/name or corp_acct_no is null" \
       --not-null="active" \
       --match="active/^(Y|N|1|2|3)$/" \
       --match="corp_acct_no/[a-zA-Z0-9]/" \
       --rquery="((inventory_path_name != '' AND inventory_path_name IS NOT NULL AND lower(inventory_path_name) != 'default') AND (inventory_loc_seq_no IS NULL OR inventory_loc_seq_no = '')) -- [inventory_loc_seq_no] is null" \
       --rquery="((inventory_path_name != '' AND inventory_path_name IS NOT NULL AND lower(inventory_path_name) != 'default') AND (inventory_location_name IS NULL OR inventory_location_name = '')) -- [inventory_location_name] is null" \
       --match="route_no/[a-zA-Z0-9]/" \
       --match="route_name/[a-zA-Z0-9]/" \
       --match="corp_name/[a-zA-Z0-9]/" \
       --consistent-by="corp_name|corp_id" \
       --consistent-by="corp_id|corp_name" \
       --consistent-by="name|facility_code, loc_id" \
       --consistent-by="loc_id|facility_code, name" \
       --cross-reference="inventory_path_name|$LOCATION.name" \
       --cross-reference="inventory_location_name|$LOCATION.name" \
       --cross-reference="corp_id|$GL.corp_acct_no" \
       --cross-reference="corp_name|$GL.corp_acct_name"


# validate CONTRACTS ORIGINAL
# @note Check unique keyset with item_id included for MSCM only
ivalidate --case-insensitive --pretty -t $CONTRACTO \
       --log-to=validation_errors \
       --not-null=contract_number \
       --not-null=contract_start \
       --not-null=contract_end \
       --not-null=vendor_name \
       --not-null=mfr_item_id \
       --not-null=mfr_name \
       --not-null=item_uom \
       --not-null=corp_id \
       --not-null=item_descr \
       --not-null=item_qoe \
       --not-null=contract_price \
       --not-null=contract_gpo_name \
       --not-null=contract_gpo_id \
       --match="contract_number/[a-zA-Z0-9]/" \
       --match="contract_gpo_name/[a-zA-Z0-9]/" \
       --match="corp_id/[a-zA-Z0-9]/" \
       --match="corp_name/[a-zA-Z0-9]/" \
       --match="vendor_item_id/[a-zA-Z0-9]/" \
       --match="vendor_name/[a-zA-Z0-9]/" \
       --match="mfr_item_id/[a-zA-Z0-9]/" \
       --match="mfr_name/[a-zA-Z0-9]/" \
       --query="to_date(contract_end, 'YYYY-MM-DD') >= to_date(contract_start, 'YYYY-MM-DD') -- [contract_end] comes before [contract_start]" \
       --match="contract_status/^(1|2|3|A|I|Inactive|Active|Y)$/" \
       --match="item_status/^(1|2|3|A|I|Inactive|Active|Y)$/" \
       --consistent-by="corp_id|corp_name" \
       --consistent-by="corp_name|corp_id" \
       --consistent-by="mfr_name|mfr_number" \
       --consistent-by="vendor_code|vendor_name" \
       --consistent-by="vendor_name|vendor_code" \
       --cross-reference="vendor_name|$VENDOR.vendor_name" \
       --cross-reference="mfr_name|$MFR.mfr_name" \
       --cross-reference="corp_id|$GL.corp_acct_no" \
       --cross-reference="corp_name|$GL.corp_acct_name" \
       --match="contract_price/^[0-9]+(\.{0,1}[0-9]+|[0-9]*)$/" \
       --match="item_qoe/^[0-9]+(\.{0,1}[0-9]+|[0-9]*)$/" \
       --rquery="(item_uom NOT IN (SELECT code FROM uomstd) AND item_uom !~ '^[a-zA-Z0-9]{1,3}$') -- invalid item_uom" \
       --unique="contract_gpo_name, contract_number, contract_start, contract_end, vendor_name, mfr_item_id, mfr_name, item_uom, corp_id, item_id" \

# validate ITEM
# Accepted:
# --rquery="mfr_name IN (SELECT mfr_name FROM $ITEM WHERE mfr_name IS NOT NULL GROUP BY mfr_name HAVING count(DISTINCT mfr_number) > 1) -- same mfr_name but with different mfr_number" \
ivalidate --case-insensitive --pretty -t $ITEM \
       --log-to=validation_errors \
       --not-null="item_id" \
       --match="item_id/[a-zA-Z0-9]/" \
       --not-null="item_descr" \
       --match="item_descr/[a-zA-Z0-9]/" \
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
       --unique="item_id, corp_id, vendor_code, item_uom" \
       --cross-reference="vendor_code|$VENDOR.vendor_code" \
       --cross-reference="vendor_name|$VENDOR.vendor_name" \
       --cross-reference="mfr_number|$MFR.mfr_number" \
       --cross-reference="mfr_name|$MFR.mfr_name" \
       --cross-reference="corp_id|$GL.corp_acct_no" \
       --cross-reference="corp_name|$GL.corp_acct_name" \
       --consistent-by="corp_id|corp_name" \
       --consistent-by="corp_name|corp_id" \
       --consistent-by="mfr_name|mfr_number" \
       --consistent-by="vendor_code|vendor_name" \
       --consistent-by="vendor_name|vendor_code" \
       --rquery="(item_uom NOT IN (SELECT code FROM uomstd) AND item_uom !~ '^[a-zA-Z0-9]{1,3}$') -- invalid item_uom" \
       --rquery="(default_uom NOT IN (SELECT code FROM uomstd) AND default_uom !~ '^[a-zA-Z0-9]{1,3}$') -- invalid default_uom" \
       --match="item_price/^[0-9]+(\.{0,1}[0-9]+|[0-9]*)$/" \
       --match="item_qoe/^[0-9]+(\.{0,1}[0-9]+|[0-9]*)$/"

# validate PO
ivalidate --case-insensitive --pretty -t $PO \
       --log-to=validation_errors \
       --not-null="po_no" \
       --match="po_no/[a-zA-Z0-9]/" \
       --not-null="po_date" \
       --not-null="corp_id" \
       --match="corp_id/[a-zA-Z0-9]/" \
       --not-null="corp_name" \
       --match="corp_name/[a-zA-Z0-9]/" \
       --not-null="cost_center_id" \
       --match="cost_center_id/[a-zA-Z0-9]/" \
       --not-null="cost_center_name" \
       --match="cost_center_name/[a-zA-Z0-9]/" \
       --not-null="po_line_number" \
       --match="po_line_number/^[1-9][0-9]*$/" \
       --not-null="item_id" \
       --match="item_id/[a-zA-Z0-9]/" \
       --not-null="vendor_name" \
       --match="vendor_name/[a-zA-Z0-9]/" \
       --not-null="vendor_code" \
       --match="vendor_code/[a-zA-Z0-9]/" \
       --not-null="mfr_name" \
       --match="mfr_name/[a-zA-Z0-9]/" \
       --not-null="mfr_number" \
       --match="mfr_number/[a-zA-Z0-9]/" \
       --not-null="item_descr" \
       --consistent-by="corp_id|corp_name" \
       --consistent-by="corp_name|corp_id" \
       --consistent-by="vendor_code|vendor_name" \
       --consistent-by="vendor_name|vendor_code" \
       --consistent-by="mfr_name|mfr_number" \
       --unique="po_no, po_line_number" \
       --rquery="(item_id not like '%~%' and item_id not in (select item_id from items)) -- [item_id] does not reference [items.item_id]" \
       --cross-reference="vendor_code|$VENDOR.vendor_code" \
       --cross-reference="vendor_name|$VENDOR.vendor_name" \
       --cross-reference="mfr_number|$MFR.mfr_number" \
       --cross-reference="mfr_name|$MFR.mfr_name" \
       --cross-reference="corp_id|$GL.corp_acct_no" \
       --cross-reference="corp_name|$GL.corp_acct_name" \
       --cross-reference="cost_center_id|$GL.cc_acct_no" \
       --cross-reference="cost_center_name|$GL.cc_acct_name" \
       --rquery="(purchase_uom NOT IN (SELECT code FROM uomstd) AND purchase_uom !~ '^[a-zA-Z0-9]{1,3}$') -- invalid [purchase_uom]" \
       --rquery="((item_id IS NULL OR item_id !~ '[a-zA-Z0-9]') AND (vendor_item_id IS NULL OR vendor_item_id !~ '[a-zA-Z0-9]')) -- [vendor_item_id] is either null or invalid" \
       --match="purchase_price/^[0-9]+(\.{0,1}[0-9]+|[0-9]*)$/" \
       --match="purchase_qoe/^[0-9]+(\.{0,1}[0-9]+|[0-9]*)$/"

# do not check --match="item_descr/[a-zA-Z0-9]/" \

# validate Req
#       --consistent-by="corp_id|corp_name" \
#       --consistent-by="corp_name|corp_id" \
ivalidate --case-insensitive --pretty -t $REQ \
       --log-to=validation_errors \
       --not-null="req_no" \
       --match="req_no/[a-zA-Z0-9]/" \
       --not-null="req_date" \
       --match="req_date/[a-zA-Z0-9]/" \
       --not-null="corp_id" \
       --match="corp_id/[a-zA-Z0-9]/" \
       --not-null="corp_name" \
       --match="corp_name/[a-zA-Z0-9]/" \
       --not-null="costcenter_id" \
       --match="costcenter_id/[a-zA-Z0-9]/" \
       --not-null="req_line_number" \
       --match="req_line_number/^[1-9][0-9]*$/" \
       --not-null="item_id" \
       --match="item_id/[a-zA-Z0-9]/" \
       --not-null="vendor_name" \
       --match="vendor_name/[a-zA-Z0-9]/" \
       --not-null="vendor_code" \
       --match="vendor_code/[a-zA-Z0-9]/" \
       --rquery="(item_id not like '%~%' and item_id not in (select item_id from items)) -- item_id does not reference items.item_id" \
       --cross-reference="corp_id|$GL.corp_acct_no" \
       --cross-reference="corp_name|$GL.corp_acct_name" \
       --cross-reference="vendor_name|$VENDOR.vendor_name" \
       --cross-reference="vendor_code|$VENDOR.vendor_code" \
       --cross-reference="mfr_name|$MFR.mfr_name" \
       --cross-reference="costcenter_id|$GL.cc_acct_no" \
       --cross-reference="costcenter_name|$GL.cc_acct_name" \
       --unique="req_no, req_line_number" \

# validate USERS
ivalidate --case-insensitive --pretty -t $USER \
       --log-to=validation_errors \
       --not-null="email" \
       --unique="email" \
       --match="lower(email)/[a-z0-9][a-z0-9_\.]+@[a-z0-9][a-z0-9_\.\-]+\.[a-z0-9_\.\-]+/"


# validate INVENTORY
ivalidate --case-insensitive --pretty -t $INVENTORY \
       --log-to=validation_errors \
       --not-null="item_id" \
       --match="item_id/[a-zA-Z0-9]/" \
       --not-null="loc_id" \
       --match="loc_id/[a-zA-Z0-9]/" \
       --not-null="vendor_code" \
       --match="vendor_code/[a-zA-Z0-9]/" \
       --not-null="corp_id" \
       --match="corp_id/[a-zA-Z0-9]/" \
       --match="location_name/[a-zA-Z0-9]/" \
       --not-null="item_id" \
       --match="inventory_status/^(Active|Pending Inactive|Inactive|1|2|3)$/" \
       --cross-reference="item_id|$ITEM.item_id" \
       --cross-reference="location_name|$LOCATION.name" \
       --cross-reference="vendor_code|$VENDOR.vendor_code" \
       --cross-reference="vendor_name|$VENDOR.vendor_name" \
       --cross-reference="corp_id|$GL.corp_acct_no" \
       --cross-reference="corp_name|$GL.corp_acct_name"

ivalidate --case-insensitive --pretty -t $ULPR \
       --log-to=validation_errors \
       --match="Default_Indicator/^(Y|N|y|n)$/" \
       --not-null="email" \
       --cross-reference="email|$USER.email" \
       --cross-reference="loc_id|$LOCATION.loc_id" \
       --cross-reference="loc_name|$LOCATION.name" \
       --cross-reference="corp_no|$GL.corp_acct_no" \
       --cross-reference="corp_name|$GL.corp_acct_name" \

ivalidate --case-insensitive --pretty -t $LPR \
       --log-to=validation_errors \
       --not-null="Default_Inventory_Location_Name" \
       --cross-reference="Default_Inventory_Location_Name|$LOCATION.Inventory_Location_Name" \
       --match="loc_type/^(C|LOC_TYPE_CONSUME)$/" \
       --match="active/^(1|2|3|A|I|Y|N)$/" \
       --cross-reference="item_id|$ITEM.item_id" \
       --cross-reference="corp_acct_no|$GL.corp_acct_no" \
       --cross-reference="corp_name|$GL.corp_acct_name" \
       --cross-reference="cc_acct_no|$GL.cc_acct_no" \
       --cross-reference="cc_acct_name|$GL.cc_acct_name" \
       --cross-reference="loc_id|$LOCATION.loc_id" \
       --cross-reference="Location_Name|$LOCATION.name"

####################################################
# Create report file for every table (extract 1000 records for every error)
# These file will then be used for the Validation Report
####################################################
        
iexport -t $CONTRACTO \
        -o "$OUTPUT_DIR/$CONTRACTO.csv" -f csv --no-quote-empty --quotes --headers \
        --query="select * from (select ROW_NUMBER() OVER (PARTITION BY error) AS group_index, * 
                 FROM ( select unnest(string_to_array(validation_errors, ' || ')) as error, * from
                 $CONTRACTO order by id  ) as main) as tmp
                 where group_index <= 1000" \
        --exclude="id, validation_errors, group_index"

iexport -t $VENDOR \
        -o "$OUTPUT_DIR/$VENDOR.csv" -f csv --no-quote-empty --quotes --headers \
        --query="select * from (select ROW_NUMBER() OVER (PARTITION BY error) AS group_index, * 
                 FROM ( select unnest(string_to_array(validation_errors, ' || ')) as error, * from
                 $VENDOR order by id  ) as main) as tmp
                 where group_index <= 1000" \
        --exclude="id, validation_errors, group_index"

iexport -t $MFR \
        -o "$OUTPUT_DIR/$MFR.csv" -f csv --no-quote-empty --quotes --headers \
        --query="select * from (select ROW_NUMBER() OVER (PARTITION BY error) AS group_index, * 
                 FROM ( select unnest(string_to_array(validation_errors, ' || ')) as error, * from
                 $MFR order by id  ) as main) as tmp
                 where group_index <= 1000" \
        --exclude="id, validation_errors, group_index"

iexport -t $GL \
        -o "$OUTPUT_DIR/$GL.csv" -f csv --no-quote-empty --quotes --headers \
        --query="select * from (select ROW_NUMBER() OVER (PARTITION BY error) AS group_index, * 
                 FROM ( select unnest(string_to_array(validation_errors, ' || ')) as error, * from
                 $GL order by id  ) as main) as tmp
                 where group_index <= 1000" \
        --exclude="id, validation_errors, group_index"

iexport -t $PO \
        -o "$OUTPUT_DIR/$PO.csv" -f csv --no-quote-empty --quotes --headers \
        --query="select * from (select ROW_NUMBER() OVER (PARTITION BY error) AS group_index, * 
                 FROM ( select unnest(string_to_array(validation_errors, ' || ')) as error, * from
                 $PO order by id  ) as main) as tmp
                 where group_index <= 1000" \
        --exclude="id, validation_errors, group_index"

iexport -t $INVENTORY \
        -o "$OUTPUT_DIR/$INVENTORY.csv" -f csv --no-quote-empty --quotes --headers \
        --query="select * from (select ROW_NUMBER() OVER (PARTITION BY error) AS group_index, * 
                 FROM ( select unnest(string_to_array(validation_errors, ' || ')) as error, * from
                 $INVENTORY order by id  ) as main) as tmp
                 where group_index <= 1000" \
        --exclude="id, validation_errors, group_index"

iexport -t $REQ \
        -o "$OUTPUT_DIR/$REQ.csv" -f csv --no-quote-empty --quotes --headers \
        --query="select * from (select ROW_NUMBER() OVER (PARTITION BY error) AS group_index, * 
                 FROM ( select unnest(string_to_array(validation_errors, ' || ')) as error, * from
                 $REQ order by id  ) as main) as tmp
                 where group_index <= 1000" \
        --exclude="id, validation_errors, group_index"

iexport -t $ITEM \
        -o "$OUTPUT_DIR/$ITEM.csv" -f csv --no-quote-empty --quotes --headers \
        --query="select * from (select ROW_NUMBER() OVER (PARTITION BY error) AS group_index, * 
                 FROM ( select unnest(string_to_array(validation_errors, ' || ')) as error, * from
                 $ITEM order by id  ) as main) as tmp
                 where group_index <= 1000" \
        --exclude="id, validation_errors, group_index"

iexport -t $USER \
        -o "$OUTPUT_DIR/$USER.csv" -f csv --no-quote-empty --quotes --headers \
        --query="select * from (select ROW_NUMBER() OVER (PARTITION BY error) AS group_index, * 
                 FROM ( select unnest(string_to_array(validation_errors, ' || ')) as error, * from
                 $USER order by id  ) as main) as tmp
                 where group_index <= 1000" \
        --exclude="id, validation_errors, group_index"

iexport -t $LOCATION \
        -o "$OUTPUT_DIR/$LOCATION.csv" -f csv --no-quote-empty --quotes --headers \
        --query="select * from (select ROW_NUMBER() OVER (PARTITION BY error) AS group_index, * 
                 FROM ( select unnest(string_to_array(validation_errors, ' || ')) as error, * from
                 $LOCATION order by id  ) as main) as tmp
                 where group_index <= 1000" \
        --exclude="id, validation_errors, group_index"

iexport -t $ULPR \
        -o "$OUTPUT_DIR/$ULPR.csv" -f csv --no-quote-empty --quotes --headers \
        --query="select * from (select ROW_NUMBER() OVER (PARTITION BY error) AS group_index, * 
                 FROM ( select unnest(string_to_array(validation_errors, ' || ')) as error, * from
                 $ULPR order by id  ) as main) as tmp
                 where group_index <= 1000" \
        --exclude="id, validation_errors, group_index"

iexport -t $LPR \
        -o "$OUTPUT_DIR/$LPR.csv" -f csv --no-quote-empty --quotes --headers \
        --query="select * from (select ROW_NUMBER() OVER (PARTITION BY error) AS group_index, * 
                 FROM ( select unnest(string_to_array(validation_errors, ' || ')) as error, * from
                 $LPR order by id  ) as main) as tmp
                 where group_index <= 1000" \
        --exclude="id, validation_errors, group_index"


# Use SQL to compute the summary, write the outputs to summary.csv
# --------------------------------------------------------------
iexport --output="$OUTPUT_DIR/summary.csv" -f csv --no-quote-empty --quotes --headers \
        --query="(select 'ContractMaster' as input_file, unnest(string_to_array(validation_errors, ' || ')) as error, count(*), round((count(*) * 100)::numeric / (select count(*) from $CONTRACTO), 2)::varchar || '%' as percentage from $CONTRACTO group by error order by error) union
                 (select 'VendorMaster' as input_file, unnest(string_to_array(validation_errors, ' || ')) as error, count(*), round((count(*) * 100)::numeric / (select count(*) from $VENDOR), 2)::varchar || '%' as percentage from $VENDOR group by error order by error) union
                 (select 'ItemMaster' as input_file, unnest(string_to_array(validation_errors, ' || ')) as error, count(*), round((count(*) * 100)::numeric / (select count(*) from $ITEM), 2)::varchar || '%' as percentage from $ITEM group by error order by error) union
                 (select 'ReqHistoryLoad' as input_file, unnest(string_to_array(validation_errors, ' || ')) as error, count(*), round((count(*) * 100)::numeric / (select count(*) from $REQ), 2)::varchar || '%' as percentage from $REQ group by error order by error) union
                 (select 'MfrMaster' as input_file, unnest(string_to_array(validation_errors, ' || ')) as error, count(*), round((count(*) * 100)::numeric / (select count(*) from $MFR), 2)::varchar || '%' as percentage from $MFR group by error order by error) union
                 (select 'PurchaseOrder' as input_file, unnest(string_to_array(validation_errors, ' || ')) as error, count(*), round((count(*) * 100)::numeric / (select count(*) from $PO), 2)::varchar || '%' as percentage from $PO group by error order by error) union
                 (select 'Inventory' as input_file, unnest(string_to_array(validation_errors, ' || ')) as error, count(*), round((count(*) * 100)::numeric / (select count(*) from $INVENTORY), 2)::varchar || '%' as percentage from $INVENTORY group by error order by error) union
                 (select 'User' as input_file, unnest(string_to_array(validation_errors, ' || ')) as error, count(*), round((count(*) * 100)::numeric / (select count(*) from $USER), 2)::varchar || '%' as percentage from $USER group by error order by error) union
                 (select 'Location' as input_file, unnest(string_to_array(validation_errors, ' || ')) as error, count(*), round((count(*) * 100)::numeric / (select count(*) from $LOCATION), 2)::varchar || '%' as percentage from $LOCATION group by error order by error) union
                 (select 'GLAccount' as input_file, unnest(string_to_array(validation_errors, ' || ')) as error, count(*), round((count(*) * 100)::numeric / (select count(*) from $GL), 2)::varchar || '%' as percentage from $GL group by error order by error) union
                 (select 'UserLocationProfile' as input_file, unnest(string_to_array(validation_errors, ' || ')) as error, count(*), round((count(*) * 100)::numeric / (select count(*) from $ULPR), 2)::varchar || '%' as percentage from $ULPR group by error order by error) union
                 (select 'LocationProfile' as input_file, unnest(string_to_array(validation_errors, ' || ')) as error, count(*), round((count(*) * 100)::numeric / (select count(*) from $LPR), 2)::varchar || '%' as percentage from $LPR group by error order by error)"

# Merge summary.xls and report files into one single file with several tabs
# --input="ItemCostCenterAcctExceptions:$OUTPUT_DIR/$ITEMCOST.csv" \
imerge --output=$OUTPUT_DIR/$ORGNAME.xls \
        --input="Summary:$OUTPUT_DIR/summary.csv" \
        --input="ContractMaster:$OUTPUT_DIR/$CONTRACTO.csv" \
        --input="ItemMaster:$OUTPUT_DIR/$ITEM.csv" \
        --input="MfrMaster:$OUTPUT_DIR/$MFR.csv" \
        --input="VendorMaster:$OUTPUT_DIR/$VENDOR.csv" \
        --input="PurchaseOrder:$OUTPUT_DIR/$PO.csv" \
        --input="User:$OUTPUT_DIR/$USER.csv" \
        --input="Location:$OUTPUT_DIR/$LOCATION.csv" \
        --input="ReqHistoryLoad:$OUTPUT_DIR/$REQ.csv" \
        --input="GLAccount:$OUTPUT_DIR/$GL.csv" \
        --input="Inventory:$OUTPUT_DIR/$INVENTORY.csv" \
        --input="$ULPR:$OUTPUT_DIR/$ULPR.csv" \
        --input="$LPR:$OUTPUT_DIR/$LPR.csv"

exit
