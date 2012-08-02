// $Id:$
//
// This template code contributed by Kristin Stephens.

#include "DNP3.h"
#include "TCP_Reassembler.h"

typedef struct ByteStream{
	u_char* mData;
	int length;
} StrByteStream;

StrByteStream gDnp3Data;
int gTest = 0;
bool mEncounterFirst = false;

DNP3_Analyzer::DNP3_Analyzer(Connection* c)
: TCP_ApplicationAnalyzer(AnalyzerTag::Dnp3, c)
	{
	interp = new binpac::Dnp3::Dnp3_Conn(this);
	}

DNP3_Analyzer::~DNP3_Analyzer()
	{
	delete interp;
	}

void DNP3_Analyzer::Done()
	{
	TCP_ApplicationAnalyzer::Done();

	interp->FlowEOF(true);
	interp->FlowEOF(false);
	}

void DNP3_Analyzer::DeliverStream(int len, const u_char* data, bool orig)
	{

	
	int i;
	int j = 0;
	int dnp3_i = 0;  // index within the data block
	int dnp3_length = 0;
	u_char* tran_data = 0;  
		// actually, only one transport segment is needed. 
		// different transport segment is put into different TCP packets
	int aTranFir;   // fir field in the transport header
	int aTranFin;   // fin field in the transport header
	int aTranSeq;   // fir field in the transport header
	bool m_orig;   //true -> request; false-> response
	u_char control_field = 0;
	u_char* aTempResult = NULL;
	int aTempFormerLen = 0;
	FILE* file;

//// if it is not serial protocol data ignore
	if(data[0] != 0x05 || data[1] != 0x64)
	{
		TCP_ApplicationAnalyzer::DeliverStream(len, data, orig);
		return;
	}

//// double check the orig. in case that the first received traffic is response
	control_field = data[3];
	if( (control_field & 0x80) == 0x80 )   //true request
	{
		m_orig = true;
	}
	else
	{
		m_orig = false;
	}

//// get fin fir seq field in transport header
	aTranFir = data[10] & 0x40;
	aTranFir = aTranFir >> 6;
 	aTranFin = data[10] & 0x80;
	aTranFin = aTranFin >> 7;
	aTranSeq = data[10] & 0x3F;

	///allocate memory space for the dnp3 only data
	////parse function code. Temporarily ignore PRM bit
	if( (control_field & 0x0F) != 0x03 && (control_field & 0x0F) != 0x04 )
	{
		return;
	}
//// process the data payload; extract dnp3 application layer data directly
//   the validation of crc can be set up here in the furutre, now it is ignored
// if this is the first transport segment but not last
	dnp3_i = 0;
	if( (aTranFir == 1) && (aTranFin == 0) ){
		mEncounterFirst = true;
		
		if(len != 292) { 
			reporter->Warning("The length of the TCP payload containing the first but not last transport segment should be exactly 292 bytes.");
			return;
		}
	
		gDnp3Data.mData = (u_char*)safe_malloc(len);
		
	
		gDnp3Data.length = len;
		for(i = 0; i < 8; i++){
			gDnp3Data.mData[i]= data[i];  // keep the first 8 bytes
		}
		for(i = 0; i < (len - 10); i++){
			if( (i % 18 != 16) && (i % 18 != 17)        // does not include crc on each data block
				&& ((len - 10 - i) > 2)    // does not include last data block
				&& ( i != 0 ) )             // does not consider first byte, transport layer header
			{
				gDnp3Data.mData[ dnp3_i + 8 ] = data[ i + 10 ];
				dnp3_i++;
			}
		}
		gDnp3Data.length = dnp3_i + 8;
		return;
	}
// if fir and fin are all 0; or last segment (fin is 1)
	dnp3_i = 0;
	if( aTranFir == 0 ){
		if(mEncounterFirst == false){
			reporter->Warning("A first transport segment is missing before this transport segment.");
			return; 
		}
	
		aTempFormerLen = gDnp3Data.length;
		if( (aTranFin == 0) && (len != 292) ) { 
			reporter->Warning("This is not a last transport segment, so the length of the TCP payload should be exactly 292 bytes.");
			return;
		}
		
		aTempResult = (u_char*)safe_malloc(len + aTempFormerLen);

		for(i = 0; i < aTempFormerLen; i++){
			aTempResult[i] = gDnp3Data.mData[i];
		}
		for(i = 0; i < (len - 10); i++){
			if( (i % 18 != 16) && (i % 18 != 17)        // does not include crc on each data block
				&& ((len - 10 - i) > 2)    // does not include last data block
				&& ( i != 0 ) )             // does not consider first byte, transport layer header
			{
				aTempResult[ dnp3_i + aTempFormerLen ] = data[ i + 10 ];
				dnp3_i++;
			}
		}
		gDnp3Data.length = dnp3_i + aTempFormerLen;
		free(gDnp3Data.mData);
		gDnp3Data.mData =  aTempResult;
		if( aTranFin == 1){   // if this is the last segment
			mEncounterFirst = false;
			if(gDnp3Data.length >= 65536){ 
				reporter->Warning("Currently, we don't support DNP3 packet with length more than 65536 bytes.");
				free(gDnp3Data.mData);
				gDnp3Data.mData = NULL;
				gDnp3Data.length = 0;
				return;
			}

			gDnp3Data.mData[2] = (gDnp3Data.length -2) % 0x100;
			gDnp3Data.mData[3] = ( (gDnp3Data.length -2) & 0xFF00) >> 8;
			
			TCP_ApplicationAnalyzer::DeliverStream(gDnp3Data.length, gDnp3Data.mData, m_orig);
        		interp->NewData(m_orig, gDnp3Data.mData, (gDnp3Data.mData) + (gDnp3Data.length) );
			free(gDnp3Data.mData);
			gDnp3Data.mData = NULL;
			gDnp3Data.length = 0;
		}
			
		return;		
	}
// if fir 0 and fin is 1. the last segment
//	dnp3_i = 0;
	

// if fir and fin are all 1
	///allocate memory space for the dnp3 only data
        tran_data = (u_char*)safe_malloc(len); // definitely not more than original data payload

	if(mEncounterFirst == true){
		reporter->Warning("Before this packet, a first transport segment is found but the finish one is missing.");
	}
	dnp3_i = 0;
	for(i = 0; i < 8; i++)
	{
		tran_data[i]= data[i];  // keep the first 8 bytes
	}
	for(i = 0; i < (len - 10); i++)
	{
		if( (i % 18 != 16) && (i % 18 != 17)        // does not include crc on each data block
				&& ((len - 10 - i) > 2)    // does not include last data block
				&& ( i != 0 ) )             // does not consider first byte, transport layer header
		{
			tran_data[ dnp3_i + 8 ] = data[ i + 10 ];
			dnp3_i++;
		}
	}
	///let's print out
	tran_data[3] = 0;   // put ctrl as zero as the high-8bit 
	dnp3_length = dnp3_i + 8;
	

	TCP_ApplicationAnalyzer::DeliverStream(dnp3_length, tran_data, m_orig);
	////DNP3TCP_Analyzer::DeliverStream(len, data, orig);
	////interp->NewData(orig, data, data + len);
	interp->NewData(m_orig, tran_data, tran_data + dnp3_length);
//// free tran_data
	free(tran_data);
	
///// this is for the abnormal traffic pattern such as a a first application packet is sent
///     but no last segment is found

	mEncounterFirst = false;
	if(gDnp3Data.mData != NULL){
		
		free(gDnp3Data.mData);
		gDnp3Data.mData = NULL;
		gDnp3Data.length = 0;	
	}
	
	}

void DNP3_Analyzer::Undelivered(int seq, int len, bool orig)
	{
	}

void DNP3_Analyzer::EndpointEOF(TCP_Reassembler* endp)
	{
	TCP_ApplicationAnalyzer::EndpointEOF(endp);
	//DNP3TCP_Analyzer::EndpointEOF(endp);
	interp->FlowEOF(endp->IsOrig());
	}