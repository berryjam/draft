SELECT t1.* FROM auth_log t1 
	JOIN (SELECT phone_no,MAX(create_datetime) create_datetime FROM auth_log GROUP BY phone_no) t2
		on t1.phone_no = t2.phone_no AND t1.create_datetime = t2.create_datetime;
