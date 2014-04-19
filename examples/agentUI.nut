probe1 <- 0;
 
const html1 = @"<!DOCTYPE html>
<html lang=""en"">
    <head>
        <meta charset=""utf-8"">
        <meta http-equiv=""refresh"" content=""30"">
        <meta name=""viewport"" content=""width=device-width, initial-scale=1, maximum-scale=1, user-scalable=0"">
        <meta name=""apple-mobile-web-app-capable"" content=""yes"">
       
        <script src=""http://code.jquery.com/jquery-1.9.1.min.js""></script>
        <script src=""http://code.jquery.com/jquery-migrate-1.2.1.min.js""></script>
        <script src=""http://d2c5utp5fpfikz.cloudfront.net/2_3_1/js/bootstrap.min.js""></script>
       
        <link href=""//d2c5utp5fpfikz.cloudfront.net/2_3_1/css/bootstrap.min.css"" rel=""stylesheet"">
        <link href=""//d2c5utp5fpfikz.cloudfront.net/2_3_1/css/bootstrap-responsive.min.css"" rel=""stylesheet"">
        <link rel=""shortcut icon"" href=""//cdn.shopify.com/s/files/1/0370/6457/files/favicon.ico?802"">
        <title>impTherm</title>
    </head>
    <body style=""background-color:#666666"">
        <div class='container'>
            <div class='well' style='max-width: 640px; margin: 0 auto 10px; text-align:center;'>
       
            <img src=""//cdn.shopify.com/s/files/1/0370/6457/files/red_black_logo_side_300x100.png?800"">
               
                <h2>impTherm<h2>
                <h4>Electric Imp powered thermocouple temperature monitor</h4>
                <h2>Temperature:</h2><h1>";
const html2 = @"&degF</h1>
            <img src=""//cdn.shopify.com/s/files/1/0370/6457/files/built-for-imp_300px.png?801"">
            </div>
        </div>
    </body>
</html>";
 
http.onrequest(function(request, response) {
    if (request.body == "") {
        local html = format(html1 + ("%s", probe1) + html2);
        response.send(200, html);
    }
    else {
        response.send(500, "Internal Server Error: ");
    }
});