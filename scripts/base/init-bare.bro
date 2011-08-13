@load const.bif.bro
@load types.bif.bro

# Type declarations
type string_array: table[count] of string;
type string_set: set[string];
type addr_set: set[addr];
type count_set: set[count];
type index_vec: vector of count;
type string_vec: vector of string;

type table_string_of_string: table[string] of string;

type transport_proto: enum { unknown_transport, tcp, udp, icmp };

type conn_id: record {
	orig_h: addr;
	orig_p: port;
	resp_h: addr;
	resp_p: port;
} &log;

type icmp_conn: record {
	orig_h: addr;
	resp_h: addr;
	itype: count;
	icode: count;
	len: count;
};

type icmp_hdr: record {
	icmp_type: count;	# type of message
};

type icmp_context: record {
	id: conn_id;
	len: count;
	proto: count;
	frag_offset: count;
	bad_hdr_len: bool;
	bad_checksum: bool;
	MF: bool;
	DF: bool;
};

type dns_mapping: record {
	creation_time: time;

	req_host: string;
	req_addr: addr;

	valid: bool;
	hostname: string;
	addrs: addr_set;
};

type ftp_port: record {
	h: addr;
	p: port;
	valid: bool;	# true if format was right
};

## Extensive connection info that gets added to connection endpoints
## if :bro:id:`get_conn_extensive_info` is true.
type EndpointExtInfo: record {
	## For TCP: MSS value used by this endpoint
	mss: count &log;
	## For TCP: SACK_OK option used
	sack_ok: bool &log;
	## For TCP: Number of packets with a SACK block (indicating loss or reodering)
	sack_used: count &log;
	## For TCP: Window scale factor *offered* by this endpoint. -1 if no scaling
	## offered. Window scaling is only active if both endpoints have wscale>=0
	wscale: int &log;
	## For TCP: Was the timestamp option used?
	ts_opt_used: bool &log;
	## For TCP: Max receiver window this endpoint ever announced (already scaled)
	maxwin: count &log;
	## For TCP: Min receiver window this endpoint ever announced (already scaled)
	minwin: count &log;
	## For TCP: RTT measured at the connection handshake from the monitoring 
	## point to this endpoint. The total handshake RTT is thus the sum from
	## both endpoint. Set to 0secs if the there are problems with RTT 
	## estimation (e.g., duplicate SYNs)
	rtt: interval &log;
	## For TCP: number of SYN packets this endpoint sent.
	syns: count &log;
	## For TCP: Number of packets with seq number < max seq number seen 
	## I.e., roughly the number of loss or reodering events
	pkts_below_seq: count &log;
	## The IP TTL value of the first packet of this connection.
	first_pkt_ttl: count &log;
	## Did the TTL change for any packet after the first? 
	ttl_changed: bool &log;
};

type endpoint: record {
	size: count;	# logical size (for TCP: from seq numbers)
	state: count;

	# The following are set if use_conn_size_analyzer is T.
	num_pkts: count &optional;	# number of packets on the wire
	num_bytes_ip: count &optional;	# actual number of IP-level bytes on the wire

	ext_info: EndpointExtInfo &optional;
};

type endpoint_stats: record {
	num_pkts: count;
	num_rxmit: count;
	num_rxmit_bytes: count;
	num_in_order: count;
	num_OO: count;
	num_repl: count;
	endian_type: count;
};

type AnalyzerID: count;

module Tunnel;
export {
	## Records the identity of a the parent of a tunneled connection. 
	type Parent: record {
		## The 4-tuple of the tunnel "connection". In case of an IP-in-IP
		## tunnel the ports will be set to 0. The direction (i.e., orig and
		## resp) of the parent are set according to the tunneled connection
		## and not according to the side that established the tunnel. 
		cid: conn_id;
		## The type of tunnel.
		tunnel_type: Tunneltype;
	} &log;
} # end export
module GLOBAL;

type connection: record {
	id: conn_id;
	orig: endpoint;
	resp: endpoint;
	start_time: time;
	duration: interval;
	service: string_set;	# if empty, service hasn't been determined
	addl: string;
	hot: count;		# how hot; 0 = don't know or not hot
	history: string;
	uid: string;
	tunnel_parent: Tunnel::Parent &optional;
};

type SYN_packet: record {
	is_orig: bool;
	DF: bool;
	ttl: count;
	size: count;
	win_size: count;
	win_scale: int;
	MSS: count;
	SACK_OK: bool;
};

## This record is used for grabbing packet capturing information from
## the core with the :bro:id:`net_stats` BiF.  All counts are cumulative.
type NetStats: record {
	pkts_recvd:   count &default=0; ##< Packets received by Bro.
	pkts_dropped: count &default=0; ##< Packets dropped.
	pkts_link:    count &default=0; ##< Packets seen on the link (not always available).
};

type bro_resources: record {
	version: string;        # Bro version string
	debug: bool;            # true if compiled with --enable-debug
	start_time: time;	# start time of process
	real_time: interval;	# elapsed real time since Bro started running
	user_time: interval;	# user CPU seconds
	system_time: interval;	# system CPU seconds
	mem: count;		# maximum memory consumed, in KB
	minor_faults: count;	# page faults not requiring actual I/O
	major_faults: count;	# page faults requiring actual I/O
	num_swap: count;	# times swapped out
	blocking_input: count;	# blocking input operations
	blocking_output: count;	# blocking output operations
	num_context: count;	# number of involuntary context switches

	num_TCP_conns: count;	# current number of TCP connections
	num_UDP_conns: count;
	num_ICMP_conns: count;
	num_fragments: count;	# current number of fragments pending reassembly
	num_packets: count;	# total number packets processed to date
	num_timers: count;	# current number of pending timers
	num_events_queued: count;	# total number of events queued so far
	num_events_dispatched: count;	# same for events dispatched

	max_TCP_conns: count;	# maximum number of TCP connections, etc.
	max_UDP_conns: count;
	max_ICMP_conns: count;
	max_fragments: count;
	max_timers: count;
};


# Summary statistics of all DFA_State_Caches.
type matcher_stats: record {
	matchers: count;	# number of distinct RE matchers
	dfa_states: count;	# number of DFA states across all matchers
	computed: count;	# number of computed DFA state transitions
	mem: count;		# number of bytes used by DFA states
	hits: count;		# number of cache hits
	misses: count;		# number of cache misses
	avg_nfa_states: count;	# average # NFA states across all matchers
};

# Info provided to gap_report, and also available by get_gap_summary().
type gap_info: record {
	ack_events: count;	# how many ack events *could* have had gaps
	ack_bytes: count;	# how many bytes those covered
	gap_events: count;	# how many *did* have gaps
	gap_bytes: count;	# how many bytes were missing in the gaps:
};

# This record should be read-only.
type packet: record {
	conn: connection;
	is_orig: bool;
	seq: count;	# seq=k => it is the kth *packet* of the connection
	timestamp: time;
};

type var_sizes: table[string] of count;	# indexed by var's name, returns size

type script_id: record {
	type_name: string;
	exported: bool;
	constant: bool;
	enum_constant: bool;
	redefinable: bool;
	value: any &optional;
};

type id_table: table[string] of script_id;

type record_field: record {
	type_name: string;
	log: bool;
	value: any &optional;
	default_val: any &optional;
};

type record_field_table: table[string] of record_field;

# The following two variables are defined here until the core is not
# dependent on the names remaining as they are now.
## This is the list of capture filters indexed by some user-definable ID.
global capture_filters: table[string] of string &redef;
## This is the list of restriction filters indexed by some user-definable ID.
global restrict_filters: table[string] of string &redef;

# {precompile,install}_pcap_filter identify the filter by IDs
type PcapFilterID: enum { None };

type IPAddrAnonymization: enum {
	KEEP_ORIG_ADDR,
	SEQUENTIALLY_NUMBERED,
	RANDOM_MD5,
	PREFIX_PRESERVING_A50,
	PREFIX_PRESERVING_MD5,
};

type IPAddrAnonymizationClass: enum {
	ORIG_ADDR,	# client address
	RESP_ADDR,	# server address
	OTHER_ADDR,
};


# Events are generated by event_peer's (which may be either ourselves, or
# some remote process).
type peer_id: count;

type event_peer: record {
	id: peer_id;	# locally unique ID of peer (returned by connect())
	host: addr;
	p: port;
	is_local: bool;	# true if this peer describes the current process.
	descr: string;	# source's external_source_description
	class: string &optional;	# self-assigned class of the peer
};

type rotate_info: record {
	old_name: string;  # original filename
	new_name: string;  # file name after rotation
	open: time;        # time when opened
	close: time;       # time when closed
};


### The following aren't presently used, though they should be.
# # Structures needed for subsequence computations (str_smith_waterman):
# #
# type sw_variant: enum {
#	SW_SINGLE,
#	SW_MULTIPLE,
# };

type sw_params: record {
	# Minimum size of a substring, minimum "granularity".
	min_strlen: count &default = 3;

	# Smith-Waterman flavor to use.
	sw_variant: count &default = 0;
};

type sw_align: record {
	str: string;	# string a substring is part of
	index: count;	# at which offset
};

type sw_align_vec: vector of sw_align;

type sw_substring: record {
	str: string;	# a substring
	aligns: sw_align_vec;	# all strings of which it's a substring
	new: bool;	# true if start of new alignment
};

type sw_substring_vec: vector of sw_substring;

# Policy-level handling of pcap packets.
type pcap_packet: record {
	ts_sec: count;
	ts_usec: count;
	caplen: count;
	len: count;
	data: string;
};

# GeoIP support.
type geo_location: record {
	country_code: string &optional;
	region: string &optional;
	city: string &optional;
	latitude: double &optional;
	longitude: double &optional;
} &log;

type entropy_test_result: record {
	entropy: double;
	chi_square: double;
	mean: double;
	monte_carlo_pi: double;
	serial_correlation: double;
};

# Prototypes of Bro built-in functions.
@load strings.bif.bro
@load bro.bif.bro
@load reporter.bif.bro

global log_file_name: function(tag: string): string &redef;
global open_log_file: function(tag: string): file &redef;

# Where to store the persistent state.
const state_dir = ".state" &redef;

# Length of the delays added when storing state incrementally.
const state_write_delay = 0.01 secs &redef;

global done_with_network = F;
event net_done(t: time) { done_with_network = T; }

function log_file_name(tag: string): string
	{
	local suffix = getenv("BRO_LOG_SUFFIX") == "" ? "log" : getenv("BRO_LOG_SUFFIX");
	return fmt("%s.%s", tag, suffix);
	}

function open_log_file(tag: string): file
	{
	return open(log_file_name(tag));
	}

function add_interface(iold: string, inew: string): string
	{
	if ( iold == "" )
		return inew;
	else
		return fmt("%s %s", iold, inew);
	}
global interfaces = "" &add_func = add_interface;

function add_signature_file(sold: string, snew: string): string
	{
	if ( sold == "" )
		return snew;
	else
		return cat(sold, " ", snew);
	}
global signature_files = "" &add_func = add_signature_file;

const passive_fingerprint_file = "base/misc/p0f.fp" &redef;

# TODO: testing to see if I can remove these without causing problems.
#const ftp = 21/tcp;
#const ssh = 22/tcp;
#const telnet = 23/tcp;
#const smtp = 25/tcp;
#const domain = 53/tcp;	# note, doesn't include UDP version
#const gopher = 70/tcp;
#const finger = 79/tcp;
#const http = 80/tcp;
#const ident = 113/tcp;
#const bgp = 179/tcp;
#const rlogin = 513/tcp;

const TCP_INACTIVE = 0;
const TCP_SYN_SENT = 1;
const TCP_SYN_ACK_SENT = 2;
const TCP_PARTIAL = 3;
const TCP_ESTABLISHED = 4;
const TCP_CLOSED = 5;
const TCP_RESET = 6;

# If true, don't verify checksums.  Useful for running on altered trace
# files, and for saving a few cycles, but of course dangerous, too ...
# Note that the -C command-line option overrides the setting of this
# variable.
const ignore_checksums = F &redef;

# If true, instantiate connection state when a partial connection
# (one missing its initial establishment negotiation) is seen.
const partial_connection_ok = T &redef;

# If true, instantiate connection state when a SYN ack is seen
# but not the initial SYN (even if partial_connection_ok is false).
const tcp_SYN_ack_ok = T &redef;

# If a connection state is removed there may still be some undelivered
# data waiting in the reassembler. If true, pass this to the signature
# engine before flushing the state.
const tcp_match_undelivered = T &redef;

# Check up on the result of an initial SYN after this much time.
const tcp_SYN_timeout = 5 secs &redef;

# After a connection has closed, wait this long for further activity
# before checking whether to time out its state.
const tcp_session_timer = 6 secs &redef;

# When checking a closed connection for further activity, consider it
# inactive if there hasn't been any for this long.  Complain if the
# connection is reused before this much time has elapsed.
const tcp_connection_linger = 5 secs &redef;

# Wait this long upon seeing an initial SYN before timing out the
# connection attempt.
const tcp_attempt_delay = 5 secs &redef;

# Upon seeing a normal connection close, flush state after this much time.
const tcp_close_delay = 5 secs &redef;

# Upon seeing a RST, flush state after this much time.
const tcp_reset_delay = 5 secs &redef;

# Generate a connection_partial_close event this much time after one half
# of a partial connection closes, assuming there has been no subsequent
# activity.
const tcp_partial_close_delay = 3 secs &redef;

# If a connection belongs to an application that we don't analyze,
# time it out after this interval.  If 0 secs, then don't time it out.
const non_analyzed_lifetime = 0 secs &redef;

# If a connection is inactive, time it out after this interval.
# If 0 secs, then don't time it out.
const tcp_inactivity_timeout = 5 min &redef;
const udp_inactivity_timeout = 1 min &redef;
const icmp_inactivity_timeout = 1 min &redef;

# This many FINs/RSTs in a row constitutes a "storm".
const tcp_storm_thresh = 1000 &redef;

# The FINs/RSTs must come with this much time or less between them.
const tcp_storm_interarrival_thresh = 1 sec &redef;

# Maximum amount of data that might plausibly be sent in an initial
# flight (prior to receiving any acks).  Used to determine whether we
# must not be seeing our peer's acks.  Set to zero to turn off this
# determination.
const tcp_max_initial_window = 4096;

# If we're not seeing our peer's acks, the maximum volume of data above
# a sequence hole that we'll tolerate before assuming that there's
# been a packet drop and we should give up on tracking a connection.
# If set to zero, then we don't ever give up.
const tcp_max_above_hole_without_any_acks = 4096;

# If we've seen this much data without any of it being acked, we give up
# on that connection to avoid memory exhaustion due to buffering all that
# stuff.  If set to zero, then we don't ever give up.  Ideally, Bro would
# track the current window on a connection and use it to infer that data
# has in fact gone too far, but for now we just make this quite beefy.
const tcp_excessive_data_without_further_acks = 10 * 1024 * 1024;

# For services without a handler, these sets define which
# side of a connection is to be reassembled.
const tcp_reassembler_ports_orig: set[port] = {} &redef;
const tcp_reassembler_ports_resp: set[port] = {} &redef;

# These sets define destination ports for which the contents
# of the originator (responder, respectively) stream should
# be delivered via tcp_contents.
const tcp_content_delivery_ports_orig: table[port] of bool = {} &redef;
const tcp_content_delivery_ports_resp: table[port] of bool = {} &redef;

# To have all TCP orig->resp/resp->orig traffic reported via tcp_contents,
# redef these to T.
const tcp_content_deliver_all_orig = F &redef;
const tcp_content_deliver_all_resp = F &redef;

# These sets define destination ports for which the contents
# of the originator (responder, respectively) stream should
# be delivered via udp_contents.
const udp_content_delivery_ports_orig: table[port] of bool = {} &redef;
const udp_content_delivery_ports_resp: table[port] of bool = {} &redef;

# To have all UDP orig->resp/resp->orig traffic reported via udp_contents,
# redef these to T.
const udp_content_deliver_all_orig = F &redef;
const udp_content_deliver_all_resp = F &redef;

# Check for expired table entries after this amount of time
const table_expire_interval = 10 secs &redef;

# When expiring/serializing, don't work on more than this many table
# entries at a time.
const table_incremental_step = 5000 &redef;

# When expiring, wait this amount of time before checking the next chunk
# of entries.
const table_expire_delay = 0.01 secs &redef;

# Time to wait before timing out a DNS/NTP/RPC request.
const dns_session_timeout = 10 sec &redef;
const ntp_session_timeout = 300 sec &redef;
const rpc_timeout = 24 sec &redef;

# Time window for reordering packets (to deal with timestamp
# discrepency between multiple packet sources).
const packet_sort_window = 0 usecs &redef;

# How long to hold onto fragments for possible reassembly.  A value
# of 0.0 means "forever", which resists evasion, but can lead to
# state accrual.
const frag_timeout = 0.0 sec &redef;

# Whether to use the ConnSize analyzer to count the number of
# packets and IP-level bytes transfered by each endpoint. If
# true, these values are returned in the connection's endpoint
# record val.
const use_conn_size_analyzer = F &redef;

const UDP_INACTIVE = 0;
const UDP_ACTIVE = 1;	# means we've seen something from this endpoint

const ENDIAN_UNKNOWN = 0;
const ENDIAN_LITTLE = 1;
const ENDIAN_BIG = 2;
const ENDIAN_CONFUSED = 3;

function append_addl(c: connection, addl: string)
	{
	if ( c$addl == "" )
		c$addl= addl;

	else if ( addl !in c$addl )
		c$addl = fmt("%s %s", c$addl, addl);
	}

function append_addl_marker(c: connection, addl: string, marker: string)
	{
	if ( c$addl == "" )
		c$addl= addl;

	else if ( addl !in c$addl )
		c$addl = fmt("%s%s%s", c$addl, marker, addl);
	}


# Values for set_contents_file's "direction" argument.
const CONTENTS_NONE = 0;	# turn off recording of contents
const CONTENTS_ORIG = 1;	# record originator contents
const CONTENTS_RESP = 2;	# record responder contents
const CONTENTS_BOTH = 3;	# record both originator and responder contents

const ICMP_UNREACH_NET = 0;
const ICMP_UNREACH_HOST = 1;
const ICMP_UNREACH_PROTOCOL = 2;
const ICMP_UNREACH_PORT = 3;
const ICMP_UNREACH_NEEDFRAG = 4;
const ICMP_UNREACH_ADMIN_PROHIB = 13;
# The above list isn't exhaustive ...


# Definitions for access to packet headers.  Currently only used for
# discarders.
const IPPROTO_IP = 0;			# dummy for IP
const IPPROTO_ICMP = 1;			# control message protocol
const IPPROTO_IGMP = 2;			# group mgmt protocol
const IPPROTO_IPIP = 4;			# IP encapsulation in IP
const IPPROTO_TCP = 6;			# TCP
const IPPROTO_UDP = 17;			# user datagram protocol
const IPPROTO_RAW = 255;		# raw IP packet

type ip_hdr: record {
	hl: count;		# header length (in bytes)
	tos: count;		# type of service
	len: count;		# total length
	id: count;		# identification
	ttl: count;		# time to live
	p: count;		# protocol
	src: addr;		# source address
	dst: addr;		# dest address
};

# TCP flags.
const TH_FIN = 1;
const TH_SYN = 2;
const TH_RST = 4;
const TH_PUSH = 8;
const TH_ACK = 16;
const TH_URG = 32;
const TH_FLAGS = 63;		# (TH_FIN|TH_SYN|TH_RST|TH_ACK|TH_URG)

type tcp_hdr: record {
	sport: port;		# source port
	dport: port;		# destination port
	seq: count;		# sequence number
	ack: count;		# acknowledgement number
	hl: count;		# header length (in bytes)
	dl: count;		# data length (xxx: not in original tcphdr!)
	flags: count;		# flags
	win: count;		# window
};

type udp_hdr: record {
	sport: port;		# source port
	dport: port;		# destination port
	ulen: count;		# udp length
};


# Holds an ip_hdr and one of tcp_hdr, udp_hdr, or icmp_hdr.
type pkt_hdr: record {
	ip: ip_hdr;
	tcp: tcp_hdr &optional;
	udp: udp_hdr &optional;
	icmp: icmp_hdr &optional;
};


# If you add elements here, then for a given BPF filter as index, when
# a packet matching that filter is captured, the corresponding event handler
# will be invoked.
global secondary_filters: table[string] of event(filter: string, pkt: pkt_hdr)
	&redef;

global discarder_maxlen = 128 &redef;	# maximum amount of data passed to fnc

global discarder_check_ip: function(i: ip_hdr): bool;
global discarder_check_tcp: function(i: ip_hdr, t: tcp_hdr, d: string): bool;
global discarder_check_udp: function(i: ip_hdr, u: udp_hdr, d: string): bool;
global discarder_check_icmp: function(i: ip_hdr, ih: icmp_hdr): bool;
# End of definition of access to packet headers, discarders.

const watchdog_interval = 10 sec &redef;

# The maximum number of timers to expire after processing each new
# packet.  The value trades off spreading out the timer expiration load
# with possibly having to hold state longer.  A value of 0 means
# "process all expired timers with each new packet".
const max_timer_expires = 300 &redef;

# With a similar trade-off, this gives the number of remote events
# to process in a batch before interleaving other activity.
const max_remote_events_processed = 10 &redef;

# These need to match the definitions in Login.h.
const LOGIN_STATE_AUTHENTICATE = 0;	# trying to authenticate
const LOGIN_STATE_LOGGED_IN = 1;	# successful authentication
const LOGIN_STATE_SKIP = 2;	# skip any further processing
const LOGIN_STATE_CONFUSED = 3;	# we're confused

# It would be nice to replace these function definitions with some
# form of parameterized types.
function min_double(a: double, b: double): double { return a < b ? a : b; }
function max_double(a: double, b: double): double { return a > b ? a : b; }
function min_interval(a: interval, b: interval): interval { return a < b ? a : b; }
function max_interval(a: interval, b: interval): interval { return a > b ? a : b; }
function min_count(a: count, b: count): count { return a < b ? a : b; }
function max_count(a: count, b: count): count { return a > b ? a : b; }

global skip_authentication: set[string] &redef;
global direct_login_prompts: set[string] &redef;
global login_prompts: set[string] &redef;
global login_non_failure_msgs: set[string] &redef;
global login_failure_msgs: set[string] &redef;
global login_success_msgs: set[string] &redef;
global login_timeouts: set[string] &redef;

type mime_header_rec: record {
	name: string;
	value: string;
};
type mime_header_list: table[count] of mime_header_rec;
global mime_segment_length = 1024 &redef;
global mime_segment_overlap_length = 0 &redef;

type pm_mapping: record {
	program: count;
	version: count;
	p: port;
};

type pm_mappings: table[count] of pm_mapping;

type pm_port_request: record {
	program: count;
	version: count;
	is_tcp: bool;
};

type pm_callit_request: record {
	program: count;
	version: count;
	proc: count;
	arg_size: count;
};

# See const.bif
# const RPC_SUCCESS = 0;
# const RPC_PROG_UNAVAIL = 1;
# const RPC_PROG_MISMATCH = 2;
# const RPC_PROC_UNAVAIL = 3;
# const RPC_GARBAGE_ARGS = 4;
# const RPC_SYSTEM_ERR = 5;
# const RPC_TIMEOUT = 6;
# const RPC_AUTH_ERROR = 7;
# const RPC_UNKNOWN_ERROR = 8;

const RPC_status = {
	[RPC_SUCCESS] = "ok",
	[RPC_PROG_UNAVAIL] = "prog unavail",
	[RPC_PROG_MISMATCH] = "mismatch",
	[RPC_PROC_UNAVAIL] = "proc unavail",
	[RPC_GARBAGE_ARGS] = "garbage args",
	[RPC_SYSTEM_ERR] = "system err",
	[RPC_TIMEOUT] = "timeout",
	[RPC_AUTH_ERROR] = "auth error",
	[RPC_UNKNOWN_ERROR] = "unknown"
};

module NFS3;

export {
	# Should the read and write events return the file data that has been
	# read/written?
	const return_data = F &redef;

	# If nfs_return_data is true, how much data should be returned at most.
	const return_data_max = 512 &redef;

	# If nfs_return_data is true, whether to *only* return data if the read or write
	# offset is 0, i.e., only return data for the beginning of the file.
	const return_data_first_only = T &redef;

	# This record summarizes the general results and status of NFSv3 request/reply
	# pairs. It's part of every NFSv3 event.
	type info_t: record {
		rpc_stat: rpc_status;	# If this indicates not successful, the reply record in the
					# events will be empty and contain uninitialized fields, so
					# don't use it.
		nfs_stat: status_t;

		# The start time, duration, and length in bytes of the request (call). Note that
		# the start and end time might not be accurate. For TCP, we record the
		# time when a chunk of data is delivered to the analyzer. Depending on the
		# Reassembler, this might be well after the first packet of the request
		# was received.
		req_start: time;
		req_dur: interval;
		req_len: count;

		# Same for the reply.
		rep_start: time;
		rep_dur: interval;
		rep_len: count;
	};

	# NFSv3 types. Type names are based on RFC 1813.
	type fattr_t: record {
		ftype: file_type_t;
		mode: count;
		nlink: count;
		uid: count;
		gid: count;
		size: count;
		used: count;
		rdev1: count;
		rdev2: count;
		fsid: count;
		fileid: count;
		atime: time;
		mtime: time;
		ctime: time;
	};

	type diropargs_t : record {
		dirfh: string;	# the file handle of the directory
		fname: string;	# the name of the file we are interested in
	};

	# Note, we don't need a "post_op_attr" type. We use an "fattr_t &optional"
	# instead.

	type lookup_reply_t: record {
		# If the lookup failed, dir_attr may be set.
		# If the lookup succeeded, fh is always set and obj_attr and dir_attr may be set.
		fh: string &optional;	# file handle of object looked up
		obj_attr: fattr_t &optional;	# optional attributes associated w/ file
		dir_attr: fattr_t &optional;	# optional attributes associated w/ dir.
	};

	type readargs_t: record {
		fh: string;	# file handle to read from
		offset: count;	# offset in file
		size: count;	# number of bytes to read
	};

	type read_reply_t: record {
		# If the lookup fails, attr may be set. If the lookup succeeds, attr may be set
		# and all other fields are set.
		attr: fattr_t &optional;	# attributes
		size: count &optional;	# number of bytes read
		eof: bool &optional;	# did the read end at EOF
		data: string &optional;	# the actual data; not yet implemented.
	};

	type readlink_reply_t: record {
		# If the request fails, attr may be set. If the request succeeds, attr may be
		# set and all other fields are set.
		attr: fattr_t &optional;	# attributes
		nfspath: string &optional;	# the contents of the symlink; in general a pathname as text
	};

	type writeargs_t: record {
		fh: string;	# file handle to write to
		offset: count;	# offset in file
		size: count;	# number of bytes to write
		stable: stable_how_t;	# how and when data is commited
		data: string &optional;	# the actual data; not implemented yet
	};

	type wcc_attr_t: record {
		size: count;
		atime: time;
		mtime: time;
	};

	type write_reply_t: record {
		# If the request fails, pre|post attr may be set. If the request succeeds,
		# pre|post attr may be set and all other fields are set.
		preattr: wcc_attr_t &optional;	# pre operation attributes
		postattr: fattr_t &optional;	# post operation attributes
		size: count &optional;
		commited: stable_how_t &optional;
		verf: count &optional;     # write verifier cookue
	};

	# reply for create, mkdir, symlink
	type newobj_reply_t: record {
		# If the proc failed, dir_*_attr may be set. If the proc succeeded, fh and
		# the attr's may be set. Note: no guarantee that fh is set after
		# success.
		fh: string &optional;	# file handle of object created
		obj_attr: fattr_t &optional;	# optional attributes associated w/ new object
		dir_pre_attr: wcc_attr_t &optional;	# optional attributes associated w/ dir
		dir_post_attr: fattr_t &optional;	# optional attributes associated w/ dir
	};

	# reply for remove, rmdir
	# Corresponds to "wcc_data" in the spec.
	type delobj_reply_t: record {
		dir_pre_attr: wcc_attr_t &optional;	# optional attributes associated w/ dir
		dir_post_attr: fattr_t &optional;	# optional attributes associated w/ dir
	};

	# This record is used for both readdir and readdirplus.
	type readdirargs_t: record {
		isplus: bool;	# is this a readdirplus request?
		dirfh: string;	# the directory filehandle
		cookie: count;	# cookie / pos in dir; 0 for first call
		cookieverf: count;	# the cookie verifier
		dircount: count;	# "count" field for readdir; maxcount otherwise (in bytes)
		maxcount: count &optional;	# only used for readdirplus. in bytes
	};

	type direntry_t: record {
		# fh and attr are used for readdirplus. However, even for readdirplus they may
		# not be filled out.
		fileid: count;	# e.g., inode number
		fname:  string;	# filename
		cookie: count;
		attr: fattr_t &optional;	# readdirplus: the FH attributes for the entry
		fh: string &optional;	# readdirplus: the FH for the entry
	};

	type direntry_vec_t: vector of direntry_t;

	# Used for readdir and readdirplus.
	type readdir_reply_t: record {
		# If error: dir_attr might be set. If success: dir_attr may be set, all others
		# must be set.
		isplus: bool;	# is the reply for a readdirplus request
		dir_attr: fattr_t &optional;
		cookieverf: count &optional;
		entries: direntry_vec_t &optional;
		eof: bool;	# if true, no more entries in dir.
	};

	type fsstat_t: record {
		attrs: fattr_t &optional;
		tbytes: double;
		fbytes: double;
		abytes: double;
		tfiles: double;
		ffiles: double;
		afiles: double;
		invarsec: interval;
	};
} # end export

module GLOBAL;

type ntp_msg: record {
	id: count;
	code: count;
	stratum: count;
	poll: count;
	precision: int;
	distance: interval;
	dispersion: interval;
	ref_t: time;
	originate_t: time;
	receive_t: time;
	xmit_t: time;
};


# Maps Samba command numbers to descriptive names.
global samba_cmds: table[count] of string &redef
			&default = function(c: count): string
				{ return fmt("samba-unknown-%d", c); };

type smb_hdr : record {
	command: count;
	status: count;
	flags: count;
	flags2: count;
	tid: count;
	pid: count;
	uid: count;
	mid: count;
};

type smb_trans : record {
	word_count: count;
	total_param_count: count;
	total_data_count: count;
	max_param_count: count;
	max_data_count: count;
	max_setup_count: count;
#	flags: count;
#	timeout: count;
	param_count: count;
	param_offset: count;
	data_count: count;
	data_offset: count;
	setup_count: count;
	setup0: count;
	setup1: count;
	setup2: count;
	setup3: count;
	byte_count: count;
	parameters: string;
};

type smb_trans_data : record {
	data : string;
};

type smb_tree_connect : record {
	flags: count;
	password: string;
	path: string;
	service: string;
};

type smb_negotiate : table[count] of string;

# A list of router addresses offered by the server.
type dhcp_router_list: table[count] of addr;

type dhcp_msg: record {
	op: count;	# message OP code. 1 = BOOTREQUEST, 2 = BOOTREPLY
	m_type: count;	# the type of DHCP message
	xid: count;	# transaction ID of a DHCP session
	h_addr: string;	# hardware address of the client
	ciaddr: addr;	# original IP address of the client
	yiaddr: addr;	# IP address assigned to the client
};

type dns_msg: record {
	id: count;

	opcode: count;
	rcode: count;

	QR: bool;
	AA: bool;
	TC: bool;
	RD: bool;
	RA: bool;
	Z: count;

	num_queries: count;
	num_answers: count;
	num_auth: count;
	num_addl: count;
};

type dns_soa: record {
	mname: string;	# primary source of data for zone
	rname: string;	# mailbox for responsible person
	serial: count;	# version number of zone
	refresh: interval;	# seconds before refreshing
	retry: interval;	# how long before retrying failed refresh
	expire: interval;	# when zone no longer authoritative
	minimum: interval;	# minimum TTL to use when exporting
};

type dns_edns_additional: record {
	query: string;
	qtype: count;
	t: count;
	payload_size: count;
	extended_rcode: count;
	version: count;
	z_field: count;
	TTL: interval;
	is_query: count;
};

type dns_tsig_additional: record {
	query: string;
	qtype: count;
	alg_name: string;
	sig: string;
	time_signed: time;
	fudge: time;
	orig_id: count;
	rr_error: count;
	is_query: count;
};

# Different values for "answer_type" in the following.  DNS_QUERY
# shouldn't occur, it's just for completeness.
const DNS_QUERY = 0;
const DNS_ANS = 1;
const DNS_AUTH = 2;
const DNS_ADDL = 3;

type dns_answer: record {
	answer_type: count;
	query: string;
	qtype: count;
	qclass: count;
	TTL: interval;
};

# For servers in these sets, omit processing the AUTH or ADDL records
# they include in their replies.
global dns_skip_auth: set[addr] &redef;
global dns_skip_addl: set[addr] &redef;

# If the following are true, then all AUTH or ADDL records are skipped.
global dns_skip_all_auth = T &redef;
global dns_skip_all_addl = T &redef;

# If a DNS request includes more than this many queries, assume it's
# non-DNS traffic and do not process it.  Set to 0 to turn off this
# functionality.
global dns_max_queries = 5;

# The maxiumum size in bytes for an SSL cipherspec.  If we see a packet that
# has bigger cipherspecs, we won't do a comparisons of cipherspecs.
const ssl_max_cipherspec_size = 68 &redef;

type X509_extensions: table[count] of string;

type X509: record {
	version: count;
	serial: string;
	subject: string;
	issuer: string;
	not_valid_before: time;
	not_valid_after: time;
};

# This is indexed with the CA's name and yields a DER (binary) encoded certificate.
const root_ca_certs: table[string] of string = {} &redef;

type http_stats_rec: record {
	num_requests: count;
	num_replies: count;
	request_version: double;
	reply_version: double;
};

type http_message_stat: record {
	start: time;		# when the request/reply line was complete
	interrupted: bool;	# whether the message is interrupted
	finish_msg: string;	# reason phrase if interrupted
	body_length: count;	# length of body processed
				#  (before finished/interrupted)
	content_gap_length: count;	# total len of gaps within body_length
	header_length: count;	# length of headers
				#  (including the req/reply line,
				#   but not CR/LF's)
};

global http_entity_data_delivery_size = 1500 &redef;

# Truncate URIs longer than this to prevent over-long URIs (usually sent
# by worms) from slowing down event processing.  A value of -1 means "do
# not truncate".
const truncate_http_URI = -1 &redef;

# IRC-related globals to which the event engine is sensitive.
type irc_join_info: record {
	nick: string;
	channel: string;
	password: string;
	usermode: string;
};
type irc_join_list: set[irc_join_info];
global irc_servers : set[addr] &redef;

# Stepping-stone globals.
const stp_delta: interval &redef;
const stp_idle_min: interval &redef;

# Don't do analysis on these sources.  Used to avoid overload from scanners.
global stp_skip_src: set[addr] &redef;

const interconn_min_interarrival: interval &redef;
const interconn_max_interarrival: interval &redef;
const interconn_max_keystroke_pkt_size: count &redef;
const interconn_default_pkt_size: count &redef;
const interconn_stat_period: interval &redef;
const interconn_stat_backoff: double &redef;

type interconn_endp_stats: record {
	num_pkts: count;
	num_keystrokes_two_in_row: count;
	num_normal_interarrivals: count;
	num_8k0_pkts: count;
	num_8k4_pkts: count;
	is_partial: bool;
	num_bytes: count;
	num_7bit_ascii: count;
	num_lines: count;
	num_normal_lines: count;
};

const backdoor_stat_period: interval &redef;
const backdoor_stat_backoff: double &redef;

type backdoor_endp_stats: record {
	is_partial: bool;
	num_pkts: count;
	num_8k0_pkts: count;
	num_8k4_pkts: count;
	num_lines: count;
	num_normal_lines: count;
	num_bytes: count;
	num_7bit_ascii: count;
};

type signature_state: record {
	sig_id:       string;     # ID of the signature
	conn:         connection; # Current connection
	is_orig:      bool;       # True if current endpoint is originator
	payload_size: count;      # Payload size of the first pkt of curr. endpoint

};

# This type is no longer used
# TODO: remove any use of this from the core.
type software_version: record {
	major: int;	# Major version number
	minor: int;	# Minor version number
	minor2: int;	# Minor subversion number
	addl: string;	# Additional version string (e.g. "beta42")
};

# This type is no longer used
# TODO: remove any use of this from the core.
type software: record {
	name: string;	# Unique name of a software, e.g., "OS"
	version: software_version;
};

# The following describe the quality of signature matches used
# for passive fingerprinting.
type OS_version_inference: enum {
	direct_inference, generic_inference, fuzzy_inference,
};

type OS_version: record {
	genre: string;	# Linux, Windows, AIX, ...
	detail: string;	# kernel version or such
	dist: count;	# how far is the host away from the sensor (TTL)?
	match_type: OS_version_inference;
};

# Defines for which subnets we should do passive fingerprinting.
global generate_OS_version_event: set[subnet] &redef;

# Type used to report load samples via load_sample().  For now,
# it's a set of names (event names, source file names, and perhaps
# <source file, line number>'s, which were seen during the sample.
type load_sample_info: set[string];

# NetFlow-related data structures.

# The following provides a mean to sort together flow headers and flow
# records at the script level.  rcvr_id equals the name of the file
# (e.g., netflow.dat) or the socket address (e.g., 127.0.0.1:5555),
# or an explicit name if specified to -y or -Y; pdu_id is just a serial
# number, ignoring any overflows.
type nfheader_id: record {
	rcvr_id: string;
	pdu_id: count;
};

type nf_v5_header: record {
	h_id: nfheader_id;	# ID for sorting, per the above
	cnt: count;
	sysuptime: interval;	# router's uptime
	exporttime: time;	# when the data was exported
	flow_seq: count;
	eng_type: count;
	eng_id: count;
	sample_int: count;
	exporter: addr;
};

type nf_v5_record: record {
	h_id: nfheader_id;
	id: conn_id;
	nexthop: addr;
	input: count;
	output: count;
	pkts: count;
	octets: count;
	first: time;
	last: time;
	tcpflag_fin: bool;	# Taken from tcpflags in NF V5; or directly.
	tcpflag_syn: bool;
	tcpflag_rst: bool;
	tcpflag_psh: bool;
	tcpflag_ack: bool;
	tcpflag_urg: bool;
	proto: count;
	tos: count;
	src_as: count;
	dst_as: count;
	src_mask: count;
	dst_mask: count;
};


# The peer record and the corresponding set type used by the
# BitTorrent analyzer.
type bittorrent_peer: record {
	h: addr;
	p: port;
};
type bittorrent_peer_set: set[bittorrent_peer];

# The benc value record and the corresponding table type used by the
# BitTorrenttracker analyzer.  Note that "benc" = Bencode ("Bee-Encode"),
# per http://en.wikipedia.org/wiki/Bencode.
type bittorrent_benc_value: record {
	i: int &optional;
	s: string &optional;
	d: string &optional;
	l: string &optional;
};
type bittorrent_benc_dir: table[string] of bittorrent_benc_value;

# The header table type used by the bittorrenttracker analyzer.
type bt_tracker_headers: table[string] of string;

@load event.bif.bro

# The filter the user has set via the -f command line options, or
# empty if none.
const cmd_line_bpf_filter = "" &redef;

# Rotate logs every x interval.
const log_rotate_interval = 0 sec &redef;

# If set, rotate logs at given time + i * log_rotate_interval.
# (string is time in 24h format, e.g., "18:00").
const log_rotate_base_time = "0:00" &redef;

# Rotate logs when they reach this size (in bytes).  Note, the
# parameter is a double rather than a count to enable easy expression
# of large values such as 1e7 or exceeding 2^32.
const log_max_size = 0.0 &redef;

# Default public key for encrypting log files.
const log_encryption_key = "<undefined>" &redef;

# Write profiling info into this file.
global profiling_file: file &redef;

# Update interval for profiling (0 disables).
const profiling_interval = 0 secs &redef;

# Multiples of profiling_interval at which (expensive) memory
# profiling is done (0 disables).
const expensive_profiling_multiple = 0 &redef;

# If true, then write segment profiling information (very high volume!)
# in addition to statistics.
const segment_profiling = F &redef;

# Output packet profiling information every <freq> secs (mode 1),
# every <freq> packets (mode 2), or every <freq> bytes (mode 3).
# Mode 0 disables.
type pkt_profile_modes: enum {
	PKT_PROFILE_MODE_NONE,
	PKT_PROFILE_MODE_SECS,
	PKT_PROFILE_MODE_PKTS,
	PKT_PROFILE_MODE_BYTES,
};
const pkt_profile_mode = PKT_PROFILE_MODE_NONE &redef;

# Frequency associated with packet profiling.
const pkt_profile_freq = 0.0 &redef;

# File where packet profiles are logged.
global pkt_profile_file: file &redef;

# Rate at which to generate load_sample events, *if* you've also
# defined a load_sample handler.  Units are inverse number of packets;
# e.g., a value of 20 means "roughly one in every 20 packets".
global load_sample_freq = 20 &redef;

# Rate at which to generate gap_report events assessing to what
# degree the measurement process appears to exhibit loss.
const gap_report_freq = 1.0 sec &redef;

# Whether we want content_gap and drop reports for partial connections
# (a connection is partial if it is missing a full handshake). Note that
# gap reports for partial connections might not be reliable.
const report_gaps_for_partial = F &redef;

# Globals associated with entire-run statistics on gaps (useful
# for final summaries).

# The CA certificate file to authorize remote Bros.
const ssl_ca_certificate = "<undefined>" &redef;

# File containing our private key and our certificate.
const ssl_private_key = "<undefined>" &redef;

# The passphrase for our private key. Keeping this undefined
# causes Bro to prompt for the passphrase.
const ssl_passphrase = "<undefined>" &redef;

# Whether the Bro-level packet filter drops packets per default or not.
const packet_filter_default = F &redef;

# Maximum size of regular expression groups for signature matching.
const sig_max_group_size = 50 &redef;

# If true, send logger messages to syslog.
const enable_syslog = F &redef;

# This is transmitted to peers receiving our events.
const peer_description = "bro" &redef;

# If true, broadcast events/state received from one peer to other peers.
# NOTE: These options are only temporary. They will disappear when we get a
# more sophisticated script-level communication framework.
const forward_remote_events = F &redef;
const forward_remote_state_changes = F &redef;

const PEER_ID_NONE = 0;

# Whether to use the connection tracker.
const use_connection_compressor = T &redef;

# Whether compressor should handle refused connections itself.
const cc_handle_resets = F &redef;

# Whether compressor should only take care of initial SYNs.
# (By default on, this is basically "connection compressor lite".)
const cc_handle_only_syns = T &redef;

# Whether compressor instantiates full state when originator sends a
# non-control packet.
const cc_instantiate_on_data = F &redef;

# Signature payload pattern types
const SIG_PATTERN_PAYLOAD = 0;
const SIG_PATTERN_HTTP = 1;
const SIG_PATTERN_FTP = 2;
const SIG_PATTERN_FINGER = 3;

# Log-levels for remote_log.
# Eventually we should create a general logging framework and merge these in.
const REMOTE_LOG_INFO = 1;
const REMOTE_LOG_ERROR = 2;

# Sources for remote_log.
const REMOTE_SRC_CHILD = 1;
const REMOTE_SRC_PARENT = 2;
const REMOTE_SRC_SCRIPT = 3;

# Synchronize trace processing at a regular basis in pseudo-realtime mode.
const remote_trace_sync_interval = 0 secs &redef;

# Number of peers across which to synchronize trace processing.
const remote_trace_sync_peers = 0 &redef;

# Whether for &synchronized state to send the old value as a consistency check.
const remote_check_sync_consistency = F &redef;

# Prepend the peer description, if set.
function prefixed_id(id: count): string
	{
	if ( peer_description == "" )
		return fmt("%s", id);
	else
		return cat(peer_description, "-", id);
	}

# Analyzer tags. The core automatically defines constants
# ANALYZER_<analyzer-name>*, e.g., ANALYZER_HTTP.
type AnalyzerTag: count;

# DPD configuration.

type dpd_protocol_config: record {
	ports: set[port] &optional;
};

const dpd_config: table[AnalyzerTag] of dpd_protocol_config = {} &redef;

# Reassemble the beginning of all TCP connections before doing
# signature-matching for protocol detection.
const dpd_reassemble_first_packets = T &redef;

# Size of per-connection buffer in bytes. If the buffer is full, data is
# deleted and lost to analyzers that are activated afterwards.
const dpd_buffer_size = 1024 &redef;

# If true, stops signature matching if dpd_buffer_size has been reached.
const dpd_match_only_beginning = T &redef;

# If true, don't consider any ports for deciding which analyzer to use.
const dpd_ignore_ports = F &redef;

# Ports which the core considers being likely used by servers.
const likely_server_ports: set[port] &redef;

# Set of all ports for which we know an analyzer.
global dpd_analyzer_ports: table[port] of set[AnalyzerTag];

# Per-incident timer managers are drained after this amount of inactivity.
const timer_mgr_inactivity_timeout = 1 min &redef;

# If true, output profiling for time-machine queries.
const time_machine_profiling = F &redef;

# If true, warns about unused event handlers at startup.
const check_for_unused_event_handlers = F &redef;

# If true, dumps all invoked event handlers at startup.
const dump_used_event_handlers = F &redef;

# If true, we suppress prints to local files if we have a receiver for
# print_hook events.  Ignored for files with a &disable_print_hook attribute.
const suppress_local_output = F &redef;

# Holds the filename of the trace file given with -w (empty if none).
const trace_output_file = "";

# If a trace file is given, dump *all* packets seen by Bro into it.
# By default, Bro applies (very few) heuristics to reduce the volume.
# A side effect of setting this to true is that we can write the
# packets out before we actually process them, which can be helpful
# for debugging in case the analysis triggers a crash.
const record_all_packets = F &redef;

# Some connections (e.g., SSH) retransmit the acknowledged last
# byte to keep the connection alive. If ignore_keep_alive_rexmit
# is set to T, such retransmissions will be excluded in the rexmit
# counter in conn_stats.
const ignore_keep_alive_rexmit = F &redef;

# Skip HTTP data portions for performance considerations (the skipped
# portion will not go through TCP reassembly).
const skip_http_data = F &redef;

# Whether the analysis engine parses IP packets encapsulated in
# UDP tunnels. See also: udp_tunnel_port, policy/udp-tunnel.bro.
const parse_udp_tunnels = F &redef;

module Tunnel;
export {
	## Whether to decapsulate IP tunnels (IPinIP, 6in4, 6to4)
	const decapsulate_ip = F &redef;

	## Whether to decapsulate URDP tunnels (e.g., Teredo, IPv4 in UDP)
	const decapsulate_udp = F &redef;

	## If decapsulating UDP: the set of ports for which to do so. 
	## Can be overridden by :bro:id:`Tunnel::udp_tunnel_allports`
	const udp_tunnel_ports: set[port] = { 
		3544/udp,    # Teredo 
		5072/udp,    # AYIAY
	} &redef;

	## If udp_tunnel_allports is T :bro:id:`udp_tunnel_ports` is ignored and we
	## check every UDP packet for tunnels. 
	const udp_tunnel_allports = F &redef;
} # end export
module GLOBAL;

## If true, run the ConnExtInfo_Analyzer and populate connection
## :bro:type:`endpoint` (``conn$resp``, ``conn$orig``) with
## :bro:type:`EndpointExtInfo`.
const get_conn_extensive_info = F &redef;


# Load the logging framework here because it uses fairly deep integration with 
# BiFs and script-land defined types.
@load base/frameworks/logging