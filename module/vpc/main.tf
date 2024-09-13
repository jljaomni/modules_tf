# VPC
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(
    {
      Name = "${var.vpc_name}-vpc"
    },
    var.tags
  )
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags = merge(
    {
      Name = "${var.vpc_name}-igw"
    },
    var.tags
  )
}

# Subnets públicas
resource "aws_subnet" "public" {
  count             = length(var.public_subnets)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.public_subnets[count.index]
  availability_zone = element(var.azs, count.index)
  map_public_ip_on_launch = true
  tags = merge(
    {
      Name = format("${var.vpc_name}-public-subnet-%s", element(var.azs, count.index))  # a, b, c, ...
    },
    var.tags
  )
}

# Subnets privadas
resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = element(var.azs, count.index)
  tags = merge(
    {
      Name = format("${var.vpc_name}-private-subnet-%s", element(var.azs, count.index))  # a, b, c, ...
    },
    var.tags
  )
}

# Tabla de rutas pública
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags = merge(
    {
      Name = "${var.vpc_name}-public-route-table"
    },
    var.tags
  )
}

# Asociar todas las subnets públicas a la tabla de rutas pública
resource "aws_route_table_association" "public_association" {
  count          = length(var.public_subnets)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Ruta a Internet Gateway para las subnets públicas
resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Elastic IP para NAT Gateway (solo si enable_nat_gateway es true)
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? (var.nat_per_az ? length(var.azs) : 1) : 0
  domain = "vpc"
  tags = merge(
    {
      Name = format("${var.vpc_name}-nat-eip-%s", element(var.azs, count.index))  # a, b, c, ...
    },
    var.tags
  )
}

# NAT Gateway (solo si enable_nat_gateway es true)
resource "aws_nat_gateway" "nat_gw" {
  count = var.enable_nat_gateway ? (var.nat_per_az ? length(var.azs) : 1) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = var.nat_per_az ? aws_subnet.public[count.index].id : aws_subnet.public[0].id

  tags = merge(
    {
      Name = format("${var.vpc_name}-nat-gateway-%s", element(var.azs, count.index))  # a, b, c, ...
    },
    var.tags
  )

  depends_on = [aws_internet_gateway.igw]
}

# Tabla de rutas privadas (solo si enable_nat_gateway es true)
resource "aws_route_table" "private" {
  count = length(var.private_subnets)
  
  vpc_id = aws_vpc.this.id
  tags = merge(
    {
      Name = format("${var.vpc_name}-private-route-table-%s", element(var.azs, count.index))  # a, b, c, ...
    },
    var.tags
  )
}

# Ruta hacia NAT Gateway en cada tabla de rutas privada (solo si enable_nat_gateway es true)
resource "aws_route" "private_route" {
  count = var.enable_nat_gateway ? length(var.private_subnets) : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  # Condicional para usar NAT Gateway o NAT Instance
  nat_gateway_id         = var.enable_nat_gateway ? (var.nat_per_az ? aws_nat_gateway.nat_gw[count.index].id : aws_nat_gateway.nat_gw[0].id) : null
  network_interface_id   = var.enable_nat_instance ? aws_instance.nat[0].primary_network_interface_id : null
}

# Asociar subnets privadas a sus respectivas tablas de rutas (solo si enable_nat_gateway es true)
resource "aws_route_table_association" "private_association" {
  count          = length(var.private_subnets)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

### NAT INSTANCE

resource "aws_security_group" "nat_instance_sg" {
  count = var.enable_nat_instance ? 1 : 0
  vpc_id = aws_vpc.this.id

  tags = merge(
    {
      Name = "${var.vpc_name}-nat-instance-sg"
    },
    var.tags
  )

  # Ingress rules (Permitir tráfico desde las subnets privadas y tráfico ICMP)
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = var.private_subnets
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = var.private_subnets
  }

  # Egress rules (Permitir todo el tráfico saliente)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "nat_ssm_role" {
  count = var.enable_nat_instance ? 1 : 0
  name_prefix = "${var.vpc_name}-nat-ssm-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(
    {
      Name = "${var.vpc_name}-nat-ssm-role"
    },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "nat_ssm_policy" {
  count      = var.enable_nat_instance ? 1 : 0
  role       = count.index == 0 ? aws_iam_role.nat_ssm_role[0].name : null
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "nat_ssm_instance_profile" {
  count = var.enable_nat_instance ? 1 : 0

  name_prefix = "${var.vpc_name}-nat-ssm-profile"
  role        = count.index == 0 ? aws_iam_role.nat_ssm_role[0].name : null

  tags = merge(
    {
      Name = "${var.vpc_name}-nat-ssm-profile"
    },
    var.tags
  )
}


resource "aws_instance" "nat" {
  count = var.enable_nat_instance ? 1 : 0

  ami                         = var.enable_nat_instance ? var.nat_instance_ami : null
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public[0].id
  associate_public_ip_address = true
  source_dest_check           = false

  security_groups = var.enable_nat_instance ? [aws_security_group.nat_instance_sg[0].id] : []

  iam_instance_profile = var.enable_nat_instance ? aws_iam_instance_profile.nat_ssm_instance_profile[0].name : null

  tags = merge(
    {
      Name = "${var.vpc_name}-nat-instance"
    },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

