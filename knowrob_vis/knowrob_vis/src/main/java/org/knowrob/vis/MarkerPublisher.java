package org.knowrob.vis;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.apache.commons.logging.Log;
import org.ros.message.Duration;
import org.ros.namespace.GraphName;
import org.ros.node.AbstractNodeMain;
import org.ros.node.ConnectedNode;
import org.ros.node.topic.Publisher;

import visualization_msgs.Marker;
import visualization_msgs.MarkerArray;

public class MarkerPublisher extends AbstractNodeMain {
	/**
	 */
	private Publisher<MarkerArray> pub = null;
	/**
	 */
	private ConnectedNode node = null;
	/**
	 * Logger of ROS node.
	 */
	private Log log = null;
	
	/**
	 * Store the markers to be published
	 */
	protected Map<String, MarkerObject> markers;
	/**
	 * Store all added markers (for highlighting)
	 */
	protected Map<String, MarkerObject> markersCache;
	/**
	 * Stores original colors of highlighted objects
	 */
	protected Map<String, float[]> highlighted;
	
	/**
	 * Counter for marker IDs
	 */
	private static int id = 0;

	private static MarkerPublisher instance = null;
	
	public static MarkerPublisher get() {
		if(instance==null) instance = new MarkerPublisher();
		return instance;
	}

	private MarkerPublisher() {
		markers =  new ConcurrentHashMap<String, MarkerObject>(8, 0.9f, 1);
		markersCache =  new ConcurrentHashMap<String, MarkerObject>(8, 0.9f, 1);
		highlighted = new ConcurrentHashMap<String, float[]>(8, 0.9f, 1);
	}

	@Override
	public void onStart(final ConnectedNode connectedNode) {
		node = connectedNode;
		pub = connectedNode.newPublisher("/visualization_marker_array", visualization_msgs.MarkerArray._TYPE);
		log = connectedNode.getLog();
	}

	@Override
	public GraphName getDefaultNodeName() {
		return GraphName.of("knowrob_marker");
	}
	
	public MarkerObject createMarker(String identifier) {
		System.err.println("CREATE MARKER: " + identifier);
		waitForNode();

		Marker m = node.getTopicMessageFactory().newFromType(visualization_msgs.Marker._TYPE);
		m.getHeader().setFrameId("/map"); // FIXME: set in prolog
		m.getHeader().setStamp(node.getCurrentTime());
		m.setNs("knowrob_vis");
		m.setId(id++);
		m.setAction(Marker.ADD);
		m.setLifetime(new Duration());
		
		MarkerObject marker = new MarkerObject(identifier, m, this);
		if(marker.hasVisual()) {
			synchronized (markers) {
				markers.put(identifier, marker);
			}
		}
		synchronized (markersCache) {
			markersCache.put(identifier, marker);
		}
		
		return marker;
	}
	
	public MarkerObject getMarker(String identifier) {
		return markersCache.get(identifier);
	}
	
	public void eraseMarker(String identifier) {
		try {
			MarkerObject m = markersCache.remove(identifier);
			if(m!=null) {
				m.getMessage().setAction(Marker.DELETE);
				highlighted.remove(identifier);
				markers.put(identifier,m);
			}
		}
		catch(Exception exc) {
			log.error("Failed to remove marker.", exc);
		}
	}
	
	public void eraseMarker(MarkerObject marker) {
		eraseMarker(marker.getIdentifier());
	}
	
	public void eraseAllMarker() {
		synchronized (markersCache) {
			while(!markersCache.keySet().isEmpty())
				eraseMarker(markersCache.keySet().iterator().next());
		}
	}
	
	public void publishMarker() {
		try {
			waitForNode();

			synchronized (markers) {
				MarkerArray arr = pub.newMessage();
				for(MarkerObject mrk : markers.values()) {
					arr.getMarkers().add(mrk.getMessage());
				}
				pub.publish(arr);
				markers.clear();
			}
		}
		catch (Exception exc) {
			log.error("Failed to publish marker.", exc);
		}
	}
	
	public void republishMarker() {
		try {
			waitForNode();

			synchronized (markersCache) {
				MarkerArray arr = pub.newMessage();
				for(MarkerObject mrk : markersCache.values()) {
					if(mrk.hasVisual()) arr.getMarkers().add(mrk.getMessage());
				}
				pub.publish(arr);
			}
		}
		catch (Exception exc) {
			log.error("Failed to publish marker.", exc);
		}
	}

	public void queueRepublish(MarkerObject markerObject) {
		if(markerObject.getHasVisual()) {
			synchronized (markers) {
				markers.put(markerObject.getIdentifier(), markerObject);
			}
		}
	}

	public void unqueueRepublish(MarkerObject markerObject) {
		synchronized (markers) {
			markers.remove(markerObject.getIdentifier());
		}
	}
	
	private void waitForNode() {
		try {
			while(node == null || pub == null) Thread.sleep(200);
		}
		catch (InterruptedException e) {
			e.printStackTrace();
		}
	}
}
