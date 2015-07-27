package io.almighty.rs.http;

import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.log4j.Logger;

import io.almighty.rs.Config;
import io.almighty.rs.db.RSDataSource;

public final class RSServlet extends HttpServlet {

	private static final long serialVersionUID = 2464603724605833400L;
	
	private static final Logger LOG = Logger.getLogger(RSServlet.class);
	
	@Override
	public void init() {
		Config.init();
		RSDataSource.init();
		
		LOG.info("RSServlet initialized.");
	}
	
	@Override
	public void doGet(HttpServletRequest request, HttpServletResponse response) {
		RequestHandler.submitViewRequest(HttpRequestType.GET, request, response);
	}
	
	@Override
	public void doPost(HttpServletRequest request, HttpServletResponse response) {
		RequestHandler.submitViewRequest(HttpRequestType.POST, request, response);
	}

}
