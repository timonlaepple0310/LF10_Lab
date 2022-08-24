const AWS = require("aws-sdk");

const s3 = new AWS.S3();

(async () => {
   await s3
   .putObject ({
        Body:"hello world!!!!!",
        Bucket:"fileuploadtestlf10",
        Key:"my-file3.txt",
        })
        .promise(); 
} )();

