# Reading in the data (the bottom table in the example where we'll balance using the units column)
import pandas as pd
import numpy as np
df = pd.read_excel(open(
    'C:\\Users\Owner\Desktop\InclusionCompanies\po_creation_raw_data.xlsx', 'rb'), sheet_name='Sheet1')

# Adding a store rank - used for giving units out to stores with more volume
df['store_rank'] = df.groupby('Store')['Units'].transform(
    np.sum).rank(ascending=False, method='dense')
df = df.sort_values(by=['store_rank'])

# Splitting data into different df's by DC and Item - have a dictionary of dataframes
dict_of_dcs = {k: v for k, v in df.groupby(['DC', 'Item'])}

# Function that will balance each of the dfs (for each DC-item)


def dc_item_balancer(df):

    Base_vendor_pck_qty = df.iloc[0, 5]
    aggsum = df['Units'].sum()

    while aggsum % Base_vendor_pck_qty != 0:
        for i in range(len(df)):
            # Current Units
            units = df.iloc[i, 3]
            # Whse_pack qty that we'll add to the item's units
            units_add = df.iloc[i, 4]
            # Adding the whse_pack to the item's current unit qty
            df.iloc[i, 3] = units + units_add
            # Balance check
            aggsum = df['Units'].sum()
            if aggsum % Base_vendor_pck_qty == 0:
                break
    return


# Pass each df through the function
for key, df in dict_of_dcs.items():
    dc_item_balancer(df)

# Balanced dfs are combined into one df
final_df = pd.concat(dict_of_dcs.values(), ignore_index=True)
final_df = final_df.iloc[:, 0:4]

# Download output
final_df.to_csv('C:\\Users\Owner\Downloads\Balanced_pos.csv')
