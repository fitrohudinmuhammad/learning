INSERT kasumi_stream_data.vinx_sample_api_test 
        SELECT * FROM EXTERNAL_QUERY("projects/digital-elysium-304405/locations/asia-northeast1/connections/vinx_api_stresstest",
        "SELECT * FROM kasumi_vinx_api WHERE create_date > current_date - 2 ;")
        WHERE id > ( SELECT coalesce(max(id),0) FROM kasumi_stream_data.vinx_sample_api_test );