function handler(event) {
    var request = event.request;
    var uri = request.uri;
    
    var params = '';
    if(('querystring' in request) && (request.querystring.length > 0)) {
        params = '?'+request.querystring;
    }
    
    if(uri.endsWith('/')) {
        if(uri !== '/') {
            var response = {
                statusCode: 301,
                statusDescription: 'Permanently moved',
                headers:
                { "location": { "value": `${uri.slice(0, -1) + params}` } } // remove trailing slash
            }
    
            return response;    
        }
        
        
    }
    //Check whether the URI is missing a file extension.
    else if (!uri.includes('.')) {
        request.uri += '/index.html';
    }
    
    

    return request;
}