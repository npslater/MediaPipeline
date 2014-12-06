# Mediapipeline

  This is an application that I built to process a large library of high-res audio files.  The application will create RAR archives
  of the local files, upload the archives to S3, and then transcode the files to 320Kbps MP3 using  ElasticTranscoder.  The archives
  will be aged-out to Glacier for inexpensive, long-term durable storage.
  
  The application is implemented as a CLI that runs on both on the local machine responsible for archiving and uploading the files, and an EC2 instance that
  deals with some of the processing that occurs in AWS, such as tagging the ElasticTranscoder output with the proper ID3 tag data.  Running a command from the CLI
  using the -h switch will print detailed usage information.
  
  The AWS resources are all created using CloudFormation, and there is a CLI command for creating the entire stack in the AWS region of choice.  The application makes
  extensive use of AWS services, including CloudFormation, S3, SQS, SNS, ElasticTranscoder, EC2, Kinesis, and DynamoDB.  With the recent service launches of AWS Lambda and
  S3 events, it will be possible to alter this architecture such that much of the SQS queuing can be eliminated.  When these new services become generally available,
  I will be making that change.
  
  While I built this application to serve a practical purpose, this is also a good example of how to do batch processing in the cloud.  Feel free to clone into this repo and play around with
  it!

## Installation

Clone the repo from github:

    $ git clone https://github.com/npslater/MediaPipeline
    
Build and install the gem locally.  I recommend using RVM:

    $ rvm gemset create mediapipeline
    $ rvm gemset use mediapipeline
    $ bundle install
    $ rake install

## Usage

Detailed usage for all the commands available in the CLI can be found by running:

    $ mediapipeline

## Contributing

1. Fork it ( https://github.com/[my-github-username]/mediapipeline/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
