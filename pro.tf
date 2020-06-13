//provider.

provider "aws" {
  region  = "ap-south-1"
  profile="KBworld"
}

// 1. creating the key.

resource "aws_key_pair" "deployer" {
  key_name   = "testkey"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAwkK3b5btYuy8IyBHqsNFgRSGUcYTcvM6jRjBuoUUgyHT4Epent/PVylS+VoBxGsa6rKAeeml6T5sSkn6ewXibASunpGy5EWBdHwzbayOKE+ZPSAONnvTFJ6riTtuSQ1gmRPpiN2HlwH/pW0Xi7HMVLnbBvgWCJr/mZGu2ei3WqSzRGhSIhlpdqZIb71BlSmNgnbLLI9ViSACGAlIfJRQ5P2xadRWPSJUNPa+7aWBwxWiXX7H5YPCexGWAb7SXg90/9DYFiXd4sHe51jqxY+IB/qTVTKN3ECY8JeK+JFPECL3i4PVwsrIqv6XepdwEwg2UBzCyviOvubk3SAIvduVBw== rsa-key-20200613"
}

output "keyop" {
	value=aws_key_pair.deployer
}

// 2. creating the Security group.
resource "aws_security_group" "allow_tls" {
  name        = "Security_01"
  description = "Allow SSH & HTTP inbound traffic"


  ingress {
    description = "allowing HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    
  }
ingress {
    description = "allowing SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Security_01"
  }
}

output "sec_op"{
	value = aws_security_group.allow_tls.name
}

// 3. creating the instance.


resource "aws_instance" "web" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "testkey"
  security_groups =["Security_01"]
 
 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Kirti Bardhan/Desktop/Keys/testkey.pem")
    host     = aws_instance.web.public_ip
  }

   provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php git -y",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd",
	    ]
  }



  tags = {
    Name = "project_os"
  }
}

output "es2"{
	value = aws_instance.web
}

// 5. creating ebs volume.

resource "aws_ebs_volume" "example" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1

  tags = {
    Name = "project_vol"
  }
}

output "ebs_vol"{
	value =aws_ebs_volume.example
}

// 6. attaching the volume.

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.example.id}"
  instance_id = "${aws_instance.web.id}"
  force_detach= true
}

// 7. configuring the volume.

resource "null_resource" "remote_01"  {
 
 depends_on = [
 aws_volume_attachment.ebs_att,
 ]
 
 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Kirti Bardhan/Desktop/Keys/testkey.pem")
    host     = aws_instance.web.public_ip
  }

 provisioner "remote-exec" {
   
  inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount /dev/xvdh /var/www/html",
      "sudo rm -rf /var/www/html/*",	
      "sudo git clone https://github.com/kbardhan/awsinstances.git /var/www/html "
	    ]
  }

}


output "vol_attach"{
	value = aws_volume_attachment.ebs_att
}
 
// 8. creating S3 bucket.

resource "aws_s3_bucket" "myprojectbucket_terra007005" {
  
  acl    = "public-read"
  versioning {
enabled=true
}
}

resource "aws_s3_bucket_object" "bucket1" {
   bucket = aws_s3_bucket.myprojectbucket_terra007005.bucket
   key = "mypic"
   acl = "public-read"
   source="C:/Users/Kirti Bardhan/Desktop/Kirti Bardhan/mypic.jpg"
   etag = filemd5("C:/Users/Kirti Bardhan/Desktop/Kirti Bardhan/mypic.jpg")

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}


// 9. creating cloudfront distribution.


resource "aws_cloudfront_distribution" "s3_distribution" {
depends_on = [
   null_resource.remote_01,
  ]  
origin {
    domain_name = "${aws_s3_bucket.myprojectbucket_terra007005.bucket_regional_domain_name}"
    origin_id   = "my_first_origin"

  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_root_object = "mypic"

 # logging_config {
 #   include_cookies = false
 #   bucket          = "mylogs.s3.amazonaws.com"
 #   prefix          = "myprefix"
 # }

 # aliases = ["mysite.example.com", "yoursite.example.com"]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "my_first_origin"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "my_first_origin"

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id  = "my_first_origin"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress             = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "IN"]
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

connection {
        type    = "ssh"
        user    = "ec2-user"
        private_key = file("C:/Users/Kirti Bardhan/Desktop/Keys/testkey.pem")
    	host     = aws_instance.web.public_ip
    }
provisioner "remote-exec" {
        inline  = [
            # "sudo su << \"EOF\" \n echo \"<img src='${self.domain_name}'>\" >> /var/www/html/index.php \n \"EOF\""
            "sudo su << EOF",
            "echo \"<center><img src='http://${self.domain_name}/${aws_s3_bucket_object.bucket1.key}' height='400px' width='400px'></center>\" >> /var/www/html/index.php",
            "EOF"
        ]
    }

}
