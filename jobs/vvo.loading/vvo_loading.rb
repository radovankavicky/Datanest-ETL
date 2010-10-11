# Loading for Slovak public procurement
#
# Copyright (C) 2009 Knowerce, s.r.o.
# 
# Written by: Stefan Urbanek
# Date: Oct 2009
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

class VvoLoading < Loading
def initialize(manager)
    super(manager)
    @defaults_domain = 'vvo'
end

def run
    source_table = 'sta_procurements'
    dataset_table = 'ds_procurements'
    joined_table = 'tmp_procurements_joined'
    regis_table = 'sta_regis_main'
	staging_schema = @manager.staging_schema

    self.phase = 'init'

    join = "
        CREATE TABLE #{staging_schema}.#{joined_table} (etl_loaded_date date)
        SELECT
            m.id,
            year,
            bulletin_id,
            procurement_id,
            customer_ico,
            rcust.name customer_company_name,
            supplier_ico,
            rsupp.name supplier_company_name,
            rsupp.region supplier_region,
            procurement_subject,
            price,
            currency,
            is_vat_included,
            customer_ico_evidence,
            supplier_ico_evidence,
            subject_evidence,
            price_evidence,
            procurement_type_id,
            document_id,
            m.source_url,
            m.date_created,
            NULL etl_loaded_date
        FROM #{staging_schema}.#{source_table} m
        LEFT JOIN #{staging_schema}.#{regis_table} rcust ON rcust.ico = customer_ico
        LEFT JOIN #{staging_schema}.#{regis_table} rsupp ON rsupp.ico = supplier_ico
        WHERE m.etl_loaded_date IS NULL
        "
    
    self.logger.info "merging with organisations"
    self.phase = 'merge'

    drop_staging_table(joined_table)
    execute_sql(join)
    
    mapping = create_identity_mapping(joined_table)
    mapping[:batch_record_code] = :document_id
    
    self.logger.info "appending new records to dataset"
    self.phase = 'append'

    append_table_with_map(joined_table, dataset_table, mapping, 
                                 :condition => "etl_loaded_date IS NULL")
    set_loaded_flag(source_table)
    finalize_dataset_loading(dataset_table)
    self.phase = 'end'
end

end