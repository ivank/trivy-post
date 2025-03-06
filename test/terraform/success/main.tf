resource "local_file" "foo" {
  content  = var.foo_content
  filename = "${path.module}/foo.bar"
}

resource "aws_alb_listener" "my-alb-listener" {
  port     = "80"
  protocol = "HTTP"
}
