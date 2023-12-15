#configured aws provider with proper credentials 

provider "aws" {

    region = "us-east-1"
    profile = "terraform-user"
}

#cerate default vpc if one not present already 

resource "aws_default_vpc" "default_vpc" {

    tags ={
        Name = "default vpc"
    }  
}

#using data souce to get all availablity zone in region 

data "aws_availability_zones" "available_zone" {}

#create default subnet if one dosent exists

resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.available_zones.names[0]

  tags = {
    Name = "default subnet"
  }
}

#create security group for the ec2 instance 

resource "aws_security_group" "ec2_security_group" {
   
   name = "ec2 security group"
   description = "allow access pm ports 8080 and 22"

   vpc_id = aws_default_vpc.default_vpc.id

   #allow access on port 8080
   ingress  {
    description = "http proxy access"
    from_port = 8080
    to_port=8080
    protocol="tcp"
    cidr_blocks=["0.0.0.0/0"]
   }

   #alliow port no 22
    ingress {
    description = "ssh access"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
   }

   egress {
    from_port = 0
    to_port = 0
    protocol = -1
    cidr_blocks = ["0.0.0.0/0"]
   }

   tags ={
    Name = "jenkins Server Security group "
   }
  
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}


# launch the ec2 instance and install website
resource "aws_instance" "ec2_instance" {
  ami                    = aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"
  subnet_id              = aws_default_subnet.default_az1.id
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]
  key_name               = "key_name"
  # user_data            = file("install_jenkins.sh")

  tags = {
    Name = "jenkins server"
  }
}


# an empty resource block
resource "null_resource" "name" {

  # ssh into the ec2 instance 
  connection {
    type        = "ssh"
    user        = "ec2_user"
    private_key = file("/Dowwnloads/Key_name.pem")
    host        = aws_instance.ec2_instance.public_ip
  }

  # copy the install_jenkins.sh file from your computer to the ec2 instance 
  provisioner "file" {
    source      = "install_Jenkins.sh"
    destination = "/temp/install_jenkins.sh"
  }

  # set permissions and run the install_jenkins.sh file
  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /temp/install_jenkins.sh",
      "sh /temp/install_jenkins.sh",

    ]
  }

  # wait for ec2 to be created
  depends_on = [aws_instance.ec2_instance]
}


# print the url of the jenkins server
output "website_url" {
  value     = join ("", ["http://", aws_instance.ec2_instance.public_dns, ":", "8080"])
}