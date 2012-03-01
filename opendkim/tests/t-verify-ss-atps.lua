-- $Id: t-verify-ss-atps.lua,v 1.4 2010/09/24 21:40:31 cm-msk Exp $

-- Copyright (c) 2009-2012, The OpenDKIM Project.  All rights reserved.

-- simple/simple verify test with ATPS
-- 
-- Confirms that a message with a valid signature passes and an ATPS result
-- is recorded

mt.echo("*** simple/simple verifying test with ATPS")

-- setup
sock = "unix:" .. mt.getcwd() .. "/t-verify-ss-atps.sock"
binpath = mt.getcwd() .. "/.."
if os.getenv("srcdir") ~= nil then
	mt.chdir(os.getenv("srcdir"))
end

-- try to start the filter
mt.startfilter(binpath .. "/opendkim", "-x", "t-verify-ss-atps.conf",
               "-p", sock)

-- try to connect to it
conn = mt.connect(sock, 40, 0.05)
if conn == nil then
	error("mt.connect() failed")
end

-- send connection information
-- mt.negotiate() is called implicitly
if mt.conninfo(conn, "localhost", "127.0.0.1") ~= nil then
	error("mt.conninfo() failed")
end
if mt.getreply(conn) ~= SMFIR_CONTINUE then
	error("mt.conninfo() unexpected reply")
end

-- send envelope macros and sender data
-- mt.helo() is called implicitly
mt.macro(conn, SMFIC_MAIL, "i", "t-verify-ss-atps")
if mt.mailfrom(conn, "user@example.com") ~= nil then
	error("mt.mailfrom() failed")
end
if mt.getreply(conn) ~= SMFIR_CONTINUE then
	error("mt.mailfrom() unexpected reply")
end

-- send headers
-- mt.rcptto() is called implicitly
if mt.header(conn, "DKIM-Signature", "v=1; a=rsa-sha256; c=relaxed/simple; d=example.com; s=test;\r\n\tt=1325791961; atpsh=sha256; atps=example.net;\r\n\tbh=3VWGQGY+cSNYd1MGM+X6hRXU0stl8JCaQtl4mbX/j2I=;\r\n\th=From:Date:Subject;\r\n\tb=HWU4M/8p+s8ysNCuKbatRvuPiU399Fip1Avl+tQnybes9P/9lr0B9MdT7FfT9XG0s\r\n\t F3gW4k6MlDjomVuJ10jizT+ubmzn2fz4vHDSPonb1sl9keAhSG0xHpUpZw2loJs0iS\r\n\t y9Hd9fV7iSO3NMdrzz2wM/n1S3b2ckjpiG/qxp9E=") ~=nil then
	error("mt.header(DKIM-Signature) failed")
end
if mt.getreply(conn) ~= SMFIR_CONTINUE then
	error("mt.header(DKIM-Signature) unexpected reply")
end
if mt.header(conn, "From", "user@example.net") ~= nil then
	error("mt.header(From) failed")
end
if mt.getreply(conn) ~= SMFIR_CONTINUE then
	error("mt.header(From) unexpected reply")
end
if mt.header(conn, "Date", "Tue, 22 Dec 2009 13:04:12 -0800") ~= nil then
	error("mt.header(Date) failed")
end
if mt.getreply(conn) ~= SMFIR_CONTINUE then
	error("mt.header(Date) unexpected reply")
end
if mt.header(conn, "Subject", "Signing test") ~= nil then
	error("mt.header(Subject) failed")
end
if mt.getreply(conn) ~= SMFIR_CONTINUE then
	error("mt.header(Subject) unexpected reply")
end

-- send EOH
if mt.eoh(conn) ~= nil then
	error("mt.eoh() failed")
end
if mt.getreply(conn) ~= SMFIR_CONTINUE then
	error("mt.eoh() unexpected reply")
end

-- send body
if mt.bodystring(conn, "This is a test!\r\n") ~= nil then
	error("mt.bodystring() failed")
end
if mt.getreply(conn) ~= SMFIR_CONTINUE then
	error("mt.bodystring() unexpected reply")
end

-- end of message; let the filter react
if mt.eom(conn) ~= nil then
	error("mt.eom() failed")
end
if mt.getreply(conn) ~= SMFIR_ACCEPT then
	error("mt.eom() unexpected reply")
end

-- verify that an Authentication-Results header field got added
if not mt.eom_check(conn, MT_HDRINSERT, "Authentication-Results") and
   not mt.eom_check(conn, MT_HDRADD, "Authentication-Results") then
	error("no Authentication-Results added")
end

-- verify that a DKIM pass result was added
n = 0
passfound = 0
atpsfound = 0
while true do
	ar = mt.getheader(conn, "Authentication-Results", n)
	if ar == nil then
		break
	end
	if string.find(ar, "dkim=pass", 1, true) ~= nil then
		passfound = 1
	end
	if string.find(ar, "dkim-atps=pass", 1, true) ~= nil then
		atpsfound = 1
	end
	n = n + 1
end
if passfound == 0 then
	error("incorrect/missing DKIM result")
end
if atpsfound == 0 then
	error("incorrect/missing ATPS result")
end

mt.disconnect(conn)
