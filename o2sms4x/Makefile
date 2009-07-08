zip:
	mkdir -p widget_tmp
	rm -rf widget_tmp/*
	cp -R o2sms.wdgt widget_tmp/
	cp -R AddressBookPlugIn/build/Release/AddressBookPlugIn.widgetplugin widget_tmp/o2sms.wdgt/
	cp -R o2sms-packaged-ppc widget_tmp/o2sms.wdgt/o2sms/
	cd widget_tmp/ && zip -r ../o2sms-ppc.wdgt.zip o2sms.wdgt -x \*.svn/*
	cd ..
	rm -rf widget_tmp/o2sms.wdgt/o2sms/
	cp -R o2sms-packaged-i386 widget_tmp/o2sms.wdgt/o2sms/
	cd widget_tmp/ && zip -r ../o2sms-i386.wdgt.zip o2sms.wdgt -x \*.svn/*
	rm -rf widget_tmp/

update-from-o2sms:
	svn export -q https://o2sms.svn.sourceforge.net/svnroot/o2sms/ /tmp/o2sms-repo
	cp /tmp/o2sms-repo/trunk/o2sms3/bin/o2sms o2sms-packaged-ppc/o2sms.pl
	cp /tmp/o2sms-repo/trunk/o2sms3/bin/o2sms o2sms-packaged-i386/o2sms.pl
	cp /tmp/o2sms-repo/trunk/o2sms3/lib/WWW/SMS/IE/* o2sms-packaged-i386/lib/WWW/SMS/IE/
	cp /tmp/o2sms-repo/trunk/o2sms3/lib/WWW/SMS/IE/* o2sms-packaged-ppc/lib/WWW/SMS/IE/
	rm -rf /tmp/o2sms-repo
	svn export -q https://o2sms.svn.sourceforge.net/svnroot/o2sms/ /tmp/tgwp-repo
	cp /tmp/tgwp-repo/trunk/testgen4web-perl/lib/TestGen4Web/Runner.pm o2sms-packaged-i386/lib/TestGen4Web/Runner.pm
	cp /tmp/tgwp-repo/trunk/testgen4web-perl/lib/TestGen4Web/Runner.pm o2sms-packaged-ppc/lib/TestGen4Web/Runner.pm
	rm -rf /tmp/tgwp-repo

#publish:
#	scp o2sms-ppc.wdgt.zip boris:/var/www/hosts/www.mackers.com/htdocs/projects/o2sms/releases/
#	scp o2sms-ppc.wdgt.zip mackers.com:/var/www/hosts/www.mackers.com/htdocs/projects/o2sms/releases/
#	scp o2sms-i386.wdgt.zip boris:/var/www/hosts/www.mackers.com/htdocs/projects/o2sms/releases/
#	scp o2sms-i386.wdgt.zip mackers.com:/var/www/hosts/www.mackers.com/htdocs/projects/o2sms/releases/

publish-sf: 
	/usr/bin/scp o2sms-ppc.wdgt.zip mackers@frs.sourceforge.net:uploads/o2sms-ppc-3.33.wdgt.zip
	/usr/bin/scp o2sms-i386.wdgt.zip mackers@frs.sourceforge.net:uploads/o2sms-i386-3.33.wdgt.zip

