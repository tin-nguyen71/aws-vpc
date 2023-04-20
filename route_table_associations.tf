################################################################################
# Database Route table association
################################################################################
resource "aws_route_table_association" "database" {
  count          = local.create_vpc && length(var.database_subnets) > 0 ? length(var.database_subnets) : 0
  subnet_id      = element(aws_subnet.database[*].id, count.index)
  route_table_id = element(aws_route_table.database[*].id, count.index)
}

################################################################################
# Intra Route table association
################################################################################
resource "aws_route_table_association" "intra" {
  count          = local.create_vpc && length(var.intra_subnets) > 0 ? length(var.intra_subnets) : 0
  subnet_id      = element(aws_subnet.intra[*].id, count.index)
  route_table_id = element(aws_route_table.intra[*].id, 0)
}

################################################################################
# Private Route table association
################################################################################
resource "aws_route_table_association" "private" {
  count     = local.create_vpc && length(var.private_subnets) > 0 ? length(var.private_subnets) : 0
  subnet_id = element(aws_subnet.private[*].id, count.index)
  route_table_id = element(
    aws_route_table.private[*].id, count.index
  )
}

################################################################################
# Public Route table association
################################################################################
resource "aws_route_table_association" "public" {
  count     = local.create_vpc && length(var.public_subnets) > 0 ? length(var.public_subnets) : 0
  subnet_id = element(aws_subnet.public[*].id, count.index)
  route_table_id = element(
    aws_route_table.public[*].id, count.index
  )
}
